// ============================
// File: functions/src/config/options.ts
// ============================
import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";

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

// ----- Shared helpers & scheduling logic -----
const clampRate = (r: number) => Math.min(5, Math.max(0.1, r));
const randExpHrs = (mean: number) => -Math.log(1 - Math.random()) * mean;

async function hasAtLeastEntries(uid: string, min = 10) {
  const snap = await db.collection(`users/${uid}/entries`).limit(min).get();
  return snap.size >= min;
}

function nextLocalTime(
  nowLocal: Date,
  s: { remindersPerDay: number; quietStartHour: number; quietEndHour: number }
) {
  const meanHrs = 24 / clampRate(s.remindersPerDay);
  const candidate = new Date(nowLocal.getTime() + randExpHrs(meanHrs) * 3_600_000);

  const start = s.quietStartHour;
  const end = s.quietEndHour;

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
  return {
    remindersPerDay: clampRate(Number(d?.remindersPerDay ?? 1)),
    tzIdentifier: String(d?.tzIdentifier ?? "UTC"),
    quietStartHour: Number(d?.quietStartHour ?? 9),
    quietEndHour: Number(d?.quietEndHour ?? 22),
  };
}

async function scheduleNext(uid: string, fromUtc = new Date()) {
  if (!(await hasAtLeastEntries(uid, 10))) {
    await db.doc(`users/${uid}`).set({ nextSendAt: null }, { merge: true });
    logger.info("[scheduleNext] threshold not met; nextSendAt=null", { uid });
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
  cutoffDays?: number;           // default 10 (or 7 if you changed it)
  allowRecentFallback?: boolean; // default false
  now?: Date;
};

async function pickEntry(uid: string, opts: PickOpts = {}) {
  const cutoffDays = opts.cutoffDays ?? 10;
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
    .limit(50)
    .get();

  if (!qs.empty) {
    const docs = qs.docs;
    const chosen = docs[Math.floor(Math.random() * docs.length)];
    const data = chosen.data() as any;
    return (data.text ?? data.content ?? "").toString().trim() || null;
  }

  // 2) Any entries older than cutoff (even if sent)
  qs = await db
    .collection(`users/${uid}/entries`)
    .where("createdAt", "<=", cutoffTS)
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  if (!qs.empty) {
    const docs = qs.docs;
    const chosen = docs[Math.floor(Math.random() * docs.length)];
    const data = chosen.data() as any;
    return (data.text ?? data.content ?? "").toString().trim() || null;
  }

  // 3) Optional: recent UNSENT (for new/active users)
  if (allowRecentFallback) {
    qs = await db
      .collection(`users/${uid}/entries`)
      .where("sent", "==", false)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();

    if (!qs.empty) {
      const docs = qs.docs;
      const chosen = docs[Math.floor(Math.random() * docs.length)];
      const data = chosen.data() as any;
      return (data.text ?? data.content ?? "").toString().trim() || null;
    }
  }

  // 4) FINAL FALLBACK: pick ANY entry (even recent & already sent)
  qs = await db
    .collection(`users/${uid}/entries`)
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  if (!qs.empty) {
    const docs = qs.docs;
    const chosen = docs[Math.floor(Math.random() * docs.length)];
    const data = chosen.data() as any;
    return (data.text ?? data.content ?? "").toString().trim() || null;
  }

  // No entries at all
  return null;
}


export {
  admin,
  db,
  logger,
  // keywords
  STOP_KEYWORDS,
  START_KEYWORDS,
  // scheduling utilities
  clampRate,
  randExpHrs,
  hasAtLeastEntries,
  nextLocalTime,
  loadSettings,
  scheduleNext,
  pickEntry,
  // user helpers
  findUserByPhone,
  applyOptOut,
  applyOptIn,
  isTwilioStopError,
};
