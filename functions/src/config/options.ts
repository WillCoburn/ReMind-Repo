// ============================
// File: functions/src/config/options.ts
// ============================
import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { smsDeliveryBlockReason } from "../sms/eligibility";
import { SERVER_LIMITS, resolveServerPlan } from "../entitlements/capabilities";
import { hasInactivityAutoPause } from "../inactivity/policy";
import { normalizeReminderSettings } from "../settings/reminders";

// ----- Global options (region) -----
setGlobalOptions({ region: "us-central1" });

// ----- Firebase init -----
if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();

// ----- Secrets (v2 API) -----
export const TWILIO_SID = defineSecret("TWILIO_SID");   // ACxxxxxxxx...
export const TWILIO_AUTH = defineSecret("TWILIO_AUTH"); // token
export const TWILIO_FROM = defineSecret("TWILIO_FROM"); // +1XXXXXXXXXX
export const TWILIO_MSID = defineSecret("TWILIO_MSID"); // optional
export const REVENUECAT_WEBHOOK_AUTH = defineSecret("REVENUECAT_WEBHOOK_AUTH");

// ----- Shared helpers & scheduling logic -----
const clampWeeklyRate = (r: number) =>
  Math.min(SERVER_LIMITS.proMaxRemindersPerWeek, Math.max(1, r));
const randExpHrs = (mean: number) => -Math.log(1 - Math.random()) * mean;

export const MIN_ENTRIES_FOR_SCHEDULING = 1;

async function hasAtLeastEntries(uid: string, min = MIN_ENTRIES_FOR_SCHEDULING) {
  const snap = await db.collection(`users/${uid}/entries`).limit(Math.max(50, min * 5)).get();
  return snap.docs.filter((doc) => {
    const data = doc.data() as any;
    return isSendableEntry(data) && !!entryBody(data);
  }).length >= min;
}

function nextLocalTime(
  nowLocal: Date,
  s: { remindersPerWeek: number; quietStartHour: number; quietEndHour: number }
) {
  const meanHrs = (24 * 7) / clampWeeklyRate(s.remindersPerWeek);
  const candidate = new Date(nowLocal.getTime() + randExpHrs(meanHrs) * 3_600_000);

  const clampHour = (h: number) => Math.min(24, Math.max(0, h));
  const start = clampHour(s.quietStartHour);
  const end = clampHour(s.quietEndHour);

  const atHour = (base: Date, h: number) => {
    const t = new Date(base);
    t.setHours(h, 0, 0, 0);
    return t;
  };

  const dayStart = new Date(candidate);
  dayStart.setHours(0, 0, 0, 0);
  const wStart = atHour(dayStart, start);
  const wEnd = atHour(dayStart, end);

  if (start <= end) {
    if (candidate < wStart) return wStart;
    if (candidate > wEnd) {
      const nextDayStart = new Date(dayStart);
      nextDayStart.setDate(nextDayStart.getDate() + 1);
      return atHour(nextDayStart, start);
    }
    return candidate;
  } else {
    // wraps midnight: allowed [0,end] U [start,24)
    const inEarly = candidate <= wEnd;
    const inLate = candidate >= wStart;
    if (inEarly || inLate) return candidate;
    return wStart;
  }
}

async function loadSettings(uid: string) {
  const snap = await db.doc(`users/${uid}/meta/settings`).get();
  const d = snap.exists ? snap.data()! : {};
  const userSnap = await db.doc(`users/${uid}`).get();
  const plan = resolvePlan(userSnap);
  const normalized = normalizeReminderSettings(d, {
    plan,
    maxRemindersPerWeek:
      plan === "pro"
        ? SERVER_LIMITS.proMaxRemindersPerWeek
        : SERVER_LIMITS.freeMaxRemindersPerWeek,
  });

  if (normalized.wasClamped) {
    const { wasClamped: _wasClamped, ...settingsWrite } = normalized;
    await db.doc(`users/${uid}/meta/settings`).set(settingsWrite, { merge: true });
    logger.warn("[loadSettings] normalized reminder settings", { uid, plan, raw: d, normalized });
  }

  return {
    remindersPerWeek: normalized.remindersPerWeek,
    tzIdentifier: normalized.tzIdentifier,
    quietStartHour: normalized.quietStartHour,
    quietEndHour: normalized.quietEndHour,
  };
}

async function scheduleNext(uid: string, fromUtc = new Date()) {
  const userSnap = await db.doc(`users/${uid}`).get();
  if (!userSnap.exists) {
    logger.info("[scheduleNext] user missing; skipping", { uid });
    return;
  }

  const blockReason = smsDeliveryBlockReason(userSnap);
  if (blockReason) {
    await db.doc(`users/${uid}`).set({ nextSendAt: null }, { merge: true });
    logger.info("[scheduleNext] SMS blocked; nextSendAt=null", { uid, blockReason });
    return;
  }

  if (hasInactivityAutoPause(userSnap) && resolvePlan(userSnap) !== "pro") {
    await db.doc(`users/${uid}`).set({ nextSendAt: null }, { merge: true });
    logger.info("[scheduleNext] inactivity auto-paused; nextSendAt=null", { uid });
    return;
  }

  if (!(await hasAtLeastEntries(uid, MIN_ENTRIES_FOR_SCHEDULING))) {
    await db.doc(`users/${uid}`).set({ nextSendAt: null }, { merge: true });
    logger.info("[scheduleNext] no sendable entries; nextSendAt=null", { uid });
    return;
  }

  const s = await loadSettings(uid);

  const tzFmt = new Intl.DateTimeFormat("en-US", {
    timeZone: s.tzIdentifier,
    timeZoneName: "longOffset",
    hour12: false,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const parts = tzFmt.formatToParts(fromUtc);
  const tzOffsetPart =
    parts.find((p) => p.type === "timeZoneName")?.value || "GMT+00:00";
  const m = tzOffsetPart.match(/GMT([+-])(\d{2}):(\d{2})/);
  let userOffsetMinutes = 0;
  if (m) {
    const sign = m[1] === "-" ? -1 : 1;
    userOffsetMinutes = sign * (parseInt(m[2], 10) * 60 + parseInt(m[3], 10));
  }
  const localNowMs = fromUtc.getTime() + userOffsetMinutes * 60_000;
  const localNow = new Date(localNowMs);

  const nextLocal = nextLocalTime(localNow, s);
  const nextUtcMs = nextLocal.getTime() - userOffsetMinutes * 60_000;
  const nextUtc = new Date(nextUtcMs);

  await db
    .doc(`users/${uid}`)
    .set(
      { nextSendAt: admin.firestore.Timestamp.fromDate(nextUtc) },
      { merge: true }
    );
}

async function findUserByPhone(phoneE164: string) {
  const snap = await db
    .collection("users")
    .where("phoneE164", "==", phoneE164)
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0];
}

const STOP_KEYWORDS = new Set(["STOP", "STOPALL", "UNSUBSCRIBE", "CANCEL", "END", "QUIT"]);
const START_KEYWORDS = new Set(["START", "YES", "UNSTOP"]);

async function applyOptOut(uid: string) {
  await db
    .doc(`users/${uid}`)
    .set({ active: false, smsOptOut: true, nextSendAt: null }, { merge: true });
}

async function applyOptIn(uid: string) {
  await db.doc(`users/${uid}`).set({ active: true, smsOptOut: false }, { merge: true });
  await scheduleNext(uid, new Date());
}

function isTwilioStopError(err: any) {
  const codeStr = err?.code != null ? String(err.code) : "";
  return (
    codeStr === "21610" ||
    /21610/.test(err?.moreInfo || "") ||
    /replied with STOP|recipient has opted out/i.test(err?.message || "")
  );
}

type PickOpts = {
  cutoffDays?: number;           // default 7
  allowRecentFallback?: boolean; // default false
  now?: Date;
};

type PickResult = {
  body: string;
  ref: FirebaseFirestore.DocumentReference | null;
};

function isSendableEntry(data: any) {
  return data?.deleted !== true && data?.archived !== true;
}

function entryBody(data: any) {
  return (data.text ?? data.content ?? "").toString().trim();
}

function pickRandomSendable(
  docs: FirebaseFirestore.QueryDocumentSnapshot[]
): PickResult | null {
  const candidates = docs
    .map((doc) => {
      const data = doc.data() as any;
      return { doc, body: entryBody(data), isSendable: isSendableEntry(data) };
    })
    .filter((candidate) => candidate.isSendable && candidate.body);
  if (candidates.length === 0) return null;

  const chosen = candidates[Math.floor(Math.random() * candidates.length)];
  return { body: chosen.body, ref: chosen.doc.ref };
}

async function pickEntry(uid: string, opts: PickOpts = {}): Promise<PickResult | null> {
  const cutoffDays = opts.cutoffDays ?? 7;
  const allowRecentFallback = opts.allowRecentFallback ?? false;
  const now = opts.now ?? new Date();

  const cutoffMs = now.getTime() - cutoffDays * 24 * 60 * 60 * 1000;
  const cutoffTS = admin.firestore.Timestamp.fromMillis(cutoffMs);

  // 1) Prefer UNSENT older than cutoff
  let qs = await db
    .collection(`users/${uid}/entries`)
    .where("sent", "==", false)
    .where("createdAt", "<=", cutoffTS)
    .orderBy("createdAt", "desc")
    .limit(200)
    .get();

  const olderUnsent = pickRandomSendable(qs.docs);
  if (olderUnsent) return olderUnsent;

  // 2) Any entries older than cutoff (even if sent)
  qs = await db
    .collection(`users/${uid}/entries`)
    .where("createdAt", "<=", cutoffTS)
    .orderBy("createdAt", "desc")
    .limit(200)
    .get();

  const olderAny = pickRandomSendable(qs.docs);
  if (olderAny) return olderAny;

  // 3) Optional: recent UNSENT (for new/active users)
  if (allowRecentFallback) {
    qs = await db
      .collection(`users/${uid}/entries`)
      .where("sent", "==", false)
      .orderBy("createdAt", "desc")
      .limit(200)
      .get();

    const recentUnsent = pickRandomSendable(qs.docs);
    if (recentUnsent) return recentUnsent;
  }

  // 4) FINAL FALLBACK: pick ANY entry (even recent & already sent)
  qs = await db
    .collection(`users/${uid}/entries`)
    .orderBy("createdAt", "desc")
    .limit(200)
    .get();

  const anyEntry = pickRandomSendable(qs.docs);
  if (anyEntry) return anyEntry;

  // No entries at all
  return null;
}

async function incrementReceivedCount(uid: string) {
  await db
    .doc(`users/${uid}`)
    .set({ receivedCount: admin.firestore.FieldValue.increment(1) }, { merge: true });
}

async function recordLastReminder(
  uid: string,
  body: string,
  opts: {
    entryRef?: FirebaseFirestore.DocumentReference | null;
    deliveredVia: "auto" | "manual";
    messageSid?: string;
  }
) {
  const text = body.trim();
  if (!text) return;

  await db.doc(`users/${uid}`).set(
    {
      lastReminder: {
        text,
        entryId: opts.entryRef?.id ?? null,
        deliveredVia: opts.deliveredVia,
        messageSid: opts.messageSid ?? null,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      lastReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}



// ---- Trial / entitlement helpers ----
function isTrialActive(user: FirebaseFirestore.DocumentSnapshot, now = new Date()) {
  const trialEndsAt = user.get("trialEndsAt") as FirebaseFirestore.Timestamp | null;
  if (!trialEndsAt) return false;
  return trialEndsAt.toDate().getTime() > now.getTime();
}

function computeActive(user: FirebaseFirestore.DocumentSnapshot, now = new Date()) {
  const optedOut = user.get("smsOptOut") === true;
  if (optedOut) return false;
  return user.get("active") !== false;
}

function resolvePlan(user: FirebaseFirestore.DocumentSnapshot): "free" | "pro" {
  return resolveServerPlan(user);
}




export {
  admin,
  db,
  logger,
  // keywords
  STOP_KEYWORDS,
  START_KEYWORDS,
  // scheduling utilities
  clampWeeklyRate,
  randExpHrs,
  hasAtLeastEntries,
  nextLocalTime,
  loadSettings,
  scheduleNext,
  pickEntry,
  incrementReceivedCount,
  recordLastReminder,
  // user helpers
  findUserByPhone,
  applyOptOut,
  applyOptIn,
  isTwilioStopError,
  //trial tracking
  isTrialActive,
  computeActive,
  resolvePlan,
};
