// ============================
// File: functions/src/index.ts
// ============================

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import twilio from "twilio";

// ----- Global options (region) -----
setGlobalOptions({ region: "us-central1" });

// ----- Firebase init -----
if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();

// ----- Secrets (v2 API) -----
const TWILIO_SID  = defineSecret("TWILIO_SID");   // ACxxxxxxxx...
const TWILIO_AUTH = defineSecret("TWILIO_AUTH");  // token
const TWILIO_FROM = defineSecret("TWILIO_FROM");  // +1XXXXXXXXXX
const TWILIO_MSID = defineSecret("TWILIO_MSID");  // MGxxxxxxxx... (optional)

// ----- Twilio helpers -----
function getTwilioClient(sid?: string, auth?: string) {
  if (!sid || !auth) throw new Error("Twilio secrets not set.");
  return twilio(sid, auth);
}
async function sendSMS(
  client: ReturnType<typeof twilio>,
  params: { to: string; body: string; from?: string; messagingServiceSid?: string }
) {
  return client.messages.create(params as any);
}

// ----- Scheduling helpers -----
type Settings = {
  remindersPerDay: number;      // 0.1..5
  tzIdentifier: string;         // e.g. "America/New_York"
  quietStartHour: number;       // 0..23 (earliest)
  quietEndHour: number;         // 0..23 (latest)
};

const clampRate = (r: number) => Math.min(5, Math.max(0.1, r));
const randExpHrs = (mean: number) => -Math.log(1 - Math.random()) * mean;

/** compute next local time inside [start,end] window (wrap across midnight supported) */
function nextLocalTime(nowLocal: Date, s: Settings): Date {
  const meanHrs = 24 / clampRate(s.remindersPerDay);
  const candidate = new Date(nowLocal.getTime() + randExpHrs(meanHrs) * 3600_000);

  const d = new Date(candidate);
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
    const inEarly = candidate <= wEnd;
    const inLate = candidate >= wStart;
    if (inEarly || inLate) return candidate;
    return wStart;
  }
}

async function loadSettings(uid: string): Promise<Settings | null> {
  const snap = await db.doc(`users/${uid}/meta/settings`).get();
  if (!snap.exists) return null;
  const d = snap.data()!;
  return {
    remindersPerDay: clampRate(Number(d.remindersPerDay || 1)),
    tzIdentifier: String(d.tzIdentifier || "UTC"),
    quietStartHour: Number(d.quietStartHour ?? 9),
    quietEndHour: Number(d.quietEndHour ?? 22),
  };
}

/** compute nextSendAt (UTC) from current UTC time using user TZ/window */
async function scheduleNext(uid: string, fromUtc = new Date()): Promise<void> {
  const s = await loadSettings(uid);
  if (!s) return;

  const tzFmt = new Intl.DateTimeFormat("en-US", {
    timeZone: s.tzIdentifier,
    timeZoneName: "longOffset",
    hour12: false,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const parts = tzFmt.formatToParts(fromUtc);
  const tzOffsetPart = parts.find((p) => p.type === "timeZoneName")?.value || "GMT+00:00";
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

  await db.doc(`users/${uid}`).set(
    { nextSendAt: admin.firestore.Timestamp.fromDate(nextUtc) },
    { merge: true }
  );
}

/** ✅ updated: pick a random UNSENT entry (sent:false) before fallback */
async function pickEntry(uid: string): Promise<string | null> {
  // 1. Prefer unsent entries
  const unsent = await db
    .collection(`users/${uid}/entries`)
    .where("sent", "==", false)
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  if (!unsent.empty) {
    const docs = unsent.docs;
    const chosen = docs[Math.floor(Math.random() * docs.length)];
    const data = chosen.data() as any;
    return (data.text ?? data.content ?? "").toString().trim() || null;
  }

  // 2. Fallback to any entries (if all sent)
  const all = await db
    .collection(`users/${uid}/entries`)
    .orderBy("createdAt", "desc")
    .limit(25)
    .get();
  if (all.empty) return null;

  const docs = all.docs;
  const chosen = docs[Math.floor(Math.random() * docs.length)];
  const data = chosen.data() as any;
  return (data.text ?? data.content ?? "").toString().trim() || null;
}

/** shared Twilio param builder */
function buildMsgParams(opts: {
  to: string;
  body: string;
  from?: string | null;
  msid?: string | null;
}) {
  const { to, body, from, msid } = opts;
  return msid ? { to, body, messagingServiceSid: msid } : { to, body, from: from! };
}

// ---------- sendOneNow (kept from your original) ----------
function twilioHttpsError(err: any): HttpsError {
  const details = {
    provider: "twilio",
    status: err?.status,
    code: err?.code,
    moreInfo: err?.moreInfo,
    message: err?.message,
  };
  logger.error("[sendOneNow] Twilio error", details);
  return new HttpsError(
    "failed-precondition",
    `Twilio ${details.code ?? ""} ${details.message ?? "send failed"}`.trim(),
    details
  );
}

export const sendOneNow = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID], invoker: "public" },
  async (req) => {
    try {
      const uid = req.auth?.uid;
      if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

      const userSnap = await db.doc(`users/${uid}`).get();
      if (!userSnap.exists) throw new HttpsError("not-found", "User not found.");

      const to = (userSnap.get("phoneE164") as string | undefined);
      if (!to) throw new HttpsError("failed-precondition", "No phone number on file.");

      const qs = await db
        .collection(`users/${uid}/entries`)
        .orderBy("createdAt", "asc")
        .limit(25)
        .get();

      const candidate = qs.docs.find((d) => {
        const data = d.data() as any;
        const noSentAt = !("sentAt" in data) || data.sentAt === null;
        const notMarkedSent = data.sent !== true;
        return noSentAt && notMarkedSent;
      }) || qs.docs[0];

      if (!candidate) throw new HttpsError("failed-precondition", "No entries available.");
      const text = (candidate.get("text") as string) || "(no text)";

      const sid = TWILIO_SID.value();
      const token = TWILIO_AUTH.value();
      const from = TWILIO_FROM.value();
      const msid = TWILIO_MSID.value();

      logger.info("[sendOneNow] env", { sidPrefix: sid?.slice(0, 2), usingMSID: Boolean(msid) });
      const client = getTwilioClient(sid, token);

      const msgParams = buildMsgParams({ to, body: text, from, msid });
      const res = await sendSMS(client, msgParams);
      logger.info("[sendOneNow] sent", { messageSid: res.sid });

      await candidate.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        deliveredVia: "sms",
        scheduledFor: null,
      });

      return { ok: true, entryId: candidate.id, messageSid: res.sid };
    } catch (err: any) {
      if (err?.moreInfo || err?.code || err?.status) throw twilioHttpsError(err);
      logger.error("[sendOneNow] unexpected error", { message: err?.message });
      throw new HttpsError("internal", err?.message ?? "Unknown error");
    }
  }
);

// ---------- applyUserSettings (computes nextSendAt) ----------
export const applyUserSettings = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID], invoker: "public" },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
    await scheduleNext(uid, new Date());
    return { ok: true };
  }
);

// ---------- minuteCron (scheduled sender) ----------
export const minuteCron = onSchedule(
  { schedule: "every 1 minutes", timeZone: "UTC", secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID] },
  async () => {
    const sid = TWILIO_SID.value();
    const token = TWILIO_AUTH.value();
    const from = TWILIO_FROM.value();
    const msid = TWILIO_MSID.value();
    const client = getTwilioClient(sid, token);

    const now = admin.firestore.Timestamp.now();
    const dueSnap = await db
      .collection("users")
      .where("active", "==", true)
      .where("nextSendAt", "<=", now)
      .limit(100)
      .get();

    if (dueSnap.empty) return;

    for (const doc of dueSnap.docs) {
      const uid = doc.id;
      const to = (doc.get("phoneE164") as string | undefined);
      if (!to) { await scheduleNext(uid, new Date()); continue; }

      try {
        const body = await pickEntry(uid);
        if (!body) { await scheduleNext(uid, new Date()); continue; }

        const msgParams = buildMsgParams({ to, body, from, msid });
        const res = await sendSMS(client, msgParams);
        logger.info("[minuteCron] sent", { uid, sid: res.sid });

        await scheduleNext(uid, new Date());
      } catch (e: any) {
        logger.error("[minuteCron] send failed", { uid, message: e?.message });
        await scheduleNext(uid, new Date());
      }
    }
  }
);
