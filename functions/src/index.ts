// ============================
// File: functions/src/index.ts
// ============================

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import Twilio, { Twilio as TwilioClient } from "twilio";
import PDFDocument from "pdfkit";

// ----- Global options (region) -----
setGlobalOptions({ region: "us-central1" });

// ----- Firebase init -----
if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();

// ----- Secrets (v2 API) -----
const TWILIO_SID = defineSecret("TWILIO_SID");   // ACxxxxxxxx...
const TWILIO_AUTH = defineSecret("TWILIO_AUTH"); // token
const TWILIO_FROM = defineSecret("TWILIO_FROM"); // +1XXXXXXXXXX
const TWILIO_MSID = defineSecret("TWILIO_MSID"); // MGxxxxxxxx... (optional Messaging Service)

// ----- Twilio helpers -----
function getTwilioClient(sid: string, auth: string): TwilioClient {
  if (!sid || !auth) throw new Error("Twilio secrets not set.");
  return Twilio(sid, auth);
}

type MsgParams =
  | { to: string; body: string; from: string; mediaUrl?: string[] }
  | { to: string; body: string; messagingServiceSid: string; mediaUrl?: string[] };

async function sendSMS(client: TwilioClient, params: MsgParams) {
  return client.messages.create(params as any);
}

function parseTwilioPayload(req: any) {
  const contentType = (req.headers["content-type"] || "").toString();

  if (contentType.includes("application/json")) {
    return (req.body ?? {}) as Record<string, any>;
  }

  if (req.body && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
    return req.body as Record<string, any>;
  }

  const raw = req.rawBody ? req.rawBody.toString("utf8") : "";
  const params = new URLSearchParams(raw);
  const data: Record<string, any> = {};
  params.forEach((value, key) => {
    data[key] = value;
  });
  return data;
}

function buildMsgParams(opts: {
  to: string;
  body: string;
  from?: string | null;
  msid?: string | null;
  mediaUrls?: string[];
}): MsgParams {
  const { to, body, from, msid, mediaUrls } = opts;
  return msid
    ? { to, body, messagingServiceSid: msid, mediaUrl: mediaUrls }
    : { to, body, from: from as string, mediaUrl: mediaUrls };
}

type HistoryEntry = {
  text: string;
  createdAt: Date | null;
};

function formatTimestamp(date: Date | null, timeZone: string) {
  if (!date) return "Unknown date";
  try {
    return new Intl.DateTimeFormat("en-US", {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone,
    }).format(date);
  } catch (err) {
    return new Intl.DateTimeFormat("en-US", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(date);
  }
}

async function generateHistoryPdf(entries: HistoryEntry[], opts: {
  timeZone: string;
  title?: string;
}): Promise<Buffer> {
  const { timeZone, title = "ReMind History" } = opts;

  const doc = new PDFDocument({ margin: 56, size: "LETTER" });
  const buffers: Buffer[] = [];

  doc.on("data", (chunk) => buffers.push(Buffer.from(chunk)));

  const bufferPromise = new Promise<Buffer>((resolve, reject) => {
    doc.on("end", () => resolve(Buffer.concat(buffers)));
    doc.on("error", (err) => reject(err));
  });

  doc.fontSize(22).text(title, { align: "center" });
  doc.moveDown();
  doc
    .fontSize(12)
    .fillColor("#555555")
    .text(`Generated on ${formatTimestamp(new Date(), timeZone)}`);
  doc.moveDown(1.5);

  entries.forEach((entry, index) => {
    const timestamp = formatTimestamp(entry.createdAt, timeZone);

    doc
      .fontSize(12)
      .fillColor("#1a1a1a")
      .text(timestamp, { continued: false });

    doc.moveDown(0.25);

    doc
      .fontSize(12)
      .fillColor("#000000")
      .text(entry.text || "(no text)", {
        width: doc.page.width - doc.page.margins.left - doc.page.margins.right,
      });

    if (index < entries.length - 1) {
      doc.moveDown(1);
    }
  });

  doc.end();

  return bufferPromise;
}

const clampRate = (r: number) => Math.min(5, Math.max(0.1, r));
const randExpHrs = (mean: number) => -Math.log(1 - Math.random()) * mean;

async function findUserByPhone(phoneE164: string) {
  const snap = await db
    .collection("users")
    .where("phoneE164", "==", phoneE164)
    .limit(1)
    .get();

  return snap.empty ? null : snap.docs[0];
}

const STOP_KEYWORDS = new Set([
  "STOP",
  "STOPALL",
  "UNSUBSCRIBE",
  "CANCEL",
  "END",
  "QUIT",
]);

const START_KEYWORDS = new Set(["START", "YES", "UNSTOP"]);

function normalizeKeyword(body: string) {
  return body.trim().toUpperCase();
}

function escapeXml(text: string) {
  return text.replace(/[<>&"']/g, (ch) => {
    switch (ch) {
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case "&":
        return "&amp;";
      case '"':
        return "&quot;";
      case "'":
        return "&apos;";
      default:
        return ch;
    }
  });
}

async function applyOptOut(uid: string) {
  await db
    .doc(`users/${uid}`)
    .set({ active: false, smsOptOut: true, nextSendAt: null }, { merge: true });
}

async function applyOptIn(uid: string) {
  await db
    .doc(`users/${uid}`)
    .set({ active: true, smsOptOut: false }, { merge: true });
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

/** ✅ total entries >= min (ANY entries, not just unsent) */
async function hasAtLeastEntries(uid: string, min = 10) {
  const snap = await db.collection(`users/${uid}/entries`).limit(min).get();
  return snap.size >= min;
}

/** next local time inside [start,end] (wrap across midnight supported) */
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
    // window wraps midnight: allowed [0,end] U [start,24)
    const inEarly = candidate <= wEnd;
    const inLate = candidate >= wStart;
    if (inEarly || inLate) return candidate;
    return wStart;
  }
}

/** ✅ Always return defaults even if settings doc doesn't exist */
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

/** ✅ compute & write users/{uid}.nextSendAt (UTC); only if ≥10 entries */
async function scheduleNext(uid: string, fromUtc = new Date()) {
  const s = await loadSettings(uid);
  // ⛔ require ≥10 total entries
  if (!(await hasAtLeastEntries(uid, 10))) {
    await db.doc(`users/${uid}`).set({ nextSendAt: null }, { merge: true });
    logger.info("[scheduleNext] threshold not met; nextSendAt=null", { uid });
    return;
  }

  // Compute user's offset at 'fromUtc'
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
    userOffsetMinutes =
      sign * (parseInt(m[2], 10) * 60 + parseInt(m[3], 10));
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

/** prefer unsent entries first; fallback to any entry */
async function pickEntry(uid: string) {
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

// ---------- sendOneNow (kept) ----------
function twilioHttpsError(err: any) {
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

      const to = userSnap.get("phoneE164") as string | undefined;
      if (!to) throw new HttpsError("failed-precondition", "No phone number on file.");

      const sid = TWILIO_SID.value();
      const token = TWILIO_AUTH.value();
      const from = TWILIO_FROM.value();
      const msid = TWILIO_MSID.value();

      const client = getTwilioClient(sid, token);
      const mode = typeof req.data?.mode === "string" ? req.data.mode : "";

      if (mode === "historyPdf") {
        const entriesSnap = await db
          .collection(`users/${uid}/entries`)
          .orderBy("createdAt", "desc")
          .get();

        if (entriesSnap.empty)
          throw new HttpsError("failed-precondition", "No entries available.");

        const entries: HistoryEntry[] = entriesSnap.docs
          .map((doc) => {
            const data = doc.data() as any;
            const createdAt = data.createdAt?.toDate?.() ?? null;
            const text = (data.text ?? data.content ?? "").toString().trim();
            return { text, createdAt };
          })
          .filter((entry) => entry.text.length > 0);

        if (entries.length === 0)
          throw new HttpsError("failed-precondition", "No entries available.");

        const settings = await loadSettings(uid);
        const pdfBuffer = await generateHistoryPdf(entries, {
          timeZone: settings.tzIdentifier,
          title: "Your ReMind History",
        });

        const bucket = admin.storage().bucket();
        const now = new Date();
        const safeTs = now.toISOString().replace(/[:.]/g, "-");
        const filePath = `exports/${uid}/history-${safeTs}.pdf`;
        const file = bucket.file(filePath);

        await file.save(pdfBuffer, {
          resumable: false,
          metadata: {
            contentType: "application/pdf",
          },
        });

        const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 6);
        const [signedUrl] = await file.getSignedUrl({
          action: "read",
          expires: expiresAt,
        });

        const msgParams = buildMsgParams({
          to,
          body: "Here is your ReMind history PDF.",
          from,
          msid,
          mediaUrls: [signedUrl],
        });

        const res = await sendSMS(client, msgParams);

        const batch = db.batch();
        entriesSnap.docs.forEach((doc) => {
          batch.set(
            doc.ref,
            {
              deliveredVia: "pdf",
            },
            { merge: true }
          );
        });
        await batch.commit();

        logger.info("[sendOneNow] history PDF sent", {
          messageSid: res.sid,
          totalEntries: entries.length,
        });

        return {
          ok: true,
          messageSid: res.sid,
          mediaUrl: signedUrl,
          expiresAt: expiresAt.toISOString(),
        };
      }

      const qs = await db
        .collection(`users/${uid}/entries`)
        .orderBy("createdAt", "asc")
        .limit(25)
        .get();

      const candidate =
        qs.docs.find((d) => {
          const data = d.data() as any;
          const noSentAt = !("sentAt" in data) || data.sentAt === null;
          const notMarkedSent = data.sent !== true;
          return noSentAt && notMarkedSent;
        }) || qs.docs[0];

      if (!candidate) throw new HttpsError("failed-precondition", "No entries available.");

      const text = (candidate.get("text") as string) || "(no text)";

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
      if (isTwilioStopError(err)) {
        const uid = req.auth?.uid as string | undefined;
        if (uid) await applyOptOut(uid);
      }

      if (err?.moreInfo || err?.code || err?.status) throw twilioHttpsError(err);
      logger.error("[sendOneNow] unexpected error", { message: err?.message });
      throw new HttpsError("internal", err?.message ?? "Unknown error");
    }
  }
);

// ---------- applyUserSettings (computes nextSendAt immediately; respects ≥10 entries) ----------
export const applyUserSettings = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID], invoker: "public" },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
    await scheduleNext(uid, new Date());
    return { ok: true };
  }
);

// ---------- WELCOME-once logic ----------
const WELCOME_TEXT =
  "Welcome to ReMind! Reply STOP to opt out or HELP for help.";

async function sendWelcomeIfNeeded(
  uid: string,
  to: string,
  client: TwilioClient,
  from?: string | null,
  msid?: string | null
) {
  const userRef = db.doc(`users/${uid}`);
  const snap = await userRef.get();
  const already = snap.get("welcomed") === true;
  if (already) return false; // once ever

  const params = buildMsgParams({
    to,
    body: WELCOME_TEXT,
    from: from ?? null,
    msid: msid ?? null,
  });

  let res: any;
  try {
    res = await client.messages.create(params as any);
  } catch (err: any) {
    if (isTwilioStopError(err)) {
      await applyOptOut(uid);
      logger.warn("[welcome] STOP detected (throw) → set inactive", { uid });
    }
    throw err;
  }

  await userRef.set(
    { welcomed: true, welcomedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );

  logger.info("[welcome] sent", { uid, sid: res.sid });
  return true;
}

// ---------- helper to resolve user's phone in E.164 from Firestore OR Auth ----------
async function getUserPhoneE164(uid: string): Promise<string | null> {
  // 1) Preferred: Firestore profile field(s)
  const userDoc = await db.doc(`users/${uid}`).get();
  const fsPhone =
    (userDoc.get("phoneE164") as string | undefined) ||
    (userDoc.get("phone") as string | undefined) ||
    null;

  if (fsPhone && /^(\+)[1-9]\d{1,14}$/.test(fsPhone)) return fsPhone;

  // 2) Fallback: Firebase Auth phone number
  try {
    const authUser = await admin.auth().getUser(uid);
    const authPhone = authUser.phoneNumber || null;
    if (authPhone && /^(\+)[1-9]\d{1,14}$/.test(authPhone)) {
      // Persist for future calls
      await db.doc(`users/${uid}`).set({ phoneE164: authPhone }, { merge: true });
      return authPhone;
    }
  } catch (e: any) {
    logger.warn("[getUserPhoneE164] auth lookup failed", { uid, message: e?.message });
  }

  return null;
}

// ---------- triggerWelcome (callable) ----------
export const triggerWelcome = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID], invoker: "public" },
  async (req) => {
    // Allow either the caller's auth uid OR an explicit data.uid for admin/testing
    const callerUid = req.auth?.uid as string | undefined;
    const targetUid = (req.data?.uid as string | undefined) || callerUid;

    if (!targetUid) {
      throw new HttpsError("unauthenticated", "Sign in or provide data.uid.");
    }

    const sid = TWILIO_SID.value();
    const token = TWILIO_AUTH.value();
    const from = TWILIO_FROM.value();
    const msid = TWILIO_MSID.value();
    const client = getTwilioClient(sid, token);

    // ✅ Ensure user is active and has default settings so scheduling works
    await db
      .doc(`users/${targetUid}`)
      .set({ active: true, smsOptOut: false }, { merge: true });
    const settingsRef = db.doc(`users/${targetUid}/meta/settings`);
    const settingsSnap = await settingsRef.get();
    if (!settingsSnap.exists) {
      await settingsRef.set(
        { remindersPerDay: 1, tzIdentifier: "UTC", quietStartHour: 9, quietEndHour: 22 },
        { merge: true }
      );
    }

    const to = await getUserPhoneE164(targetUid);
    if (!to) {
      logger.error("[triggerWelcome] no phone found", { uid: targetUid });
      throw new HttpsError("failed-precondition", "No phone on file for user.");
    }

    try {
      const sent = await sendWelcomeIfNeeded(targetUid, to, client, from, msid);
      if (sent) await scheduleNext(targetUid, new Date()); // respects ≥10 entries
      logger.info("[triggerWelcome] done", { uid: targetUid, sent });
      return { ok: true, sent };
    } catch (err: any) {
      if (isTwilioStopError(err)) {
        await applyOptOut(targetUid);
      }

      // Surface Twilio-style errors nicely
      if (err?.moreInfo || err?.code || err?.status) {
        const details = {
          provider: "twilio",
          status: err?.status,
          code: err?.code,
          moreInfo: err?.moreInfo,
          message: err?.message,
        };
        logger.error("[triggerWelcome] Twilio error", details);
        throw new HttpsError(
          "failed-precondition",
          `Twilio ${details.code ?? ""} ${details.message ?? "send failed"}`.trim(),
          details
        );
      }
      logger.error("[triggerWelcome] unexpected error", { message: err?.message });
      throw new HttpsError("internal", err?.message ?? "Unknown error");
    }
  }
);



// ---------- minuteCron (scheduled sender) ----------
export const minuteCron = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "UTC",
    secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID],
  },
  async () => {
    logger.info("[minuteCron] boot v1");

    const sid = TWILIO_SID.value();
    const token = TWILIO_AUTH.value();
    const from = TWILIO_FROM.value();
    const msid = TWILIO_MSID.value();
    const client = getTwilioClient(sid, token);

    const now = admin.firestore.Timestamp.now();

    // visibility around selection
    logger.info("[minuteCron] querying due users");
    const dueSnap = await db
      .collection("users")
      .where("active", "==", true)
      .where("nextSendAt", "<=", now)
      .limit(100)
      .get();
    logger.info("[minuteCron] due count", { count: dueSnap.size });

    if (dueSnap.empty) return;

    for (const doc of dueSnap.docs) {
      const uid = doc.id;
      const to = doc.get("phoneE164") as string | undefined;

      if (!to) {
        await scheduleNext(uid, new Date());
        continue;
      }

      try {
        // 1) Ensure welcome is sent first (once ever)
        if (doc.get("welcomed") !== true) {
          await sendWelcomeIfNeeded(uid, to, client, from, msid);
          await scheduleNext(uid, new Date()); // honors ≥10 entries
          continue; // skip entries this tick
        }

        // 2) Require ≥10 total entries before sending entries
        if (!(await hasAtLeastEntries(uid, 10))) {
          await db.doc(`users/${uid}`).set({ nextSendAt: null }, { merge: true });
          continue;
        }

        // 3) Send one entry
        const body = await pickEntry(uid);
        if (!body) {
          await scheduleNext(uid, new Date());
          continue;
        }

        // pre-send snapshot
        const toLooksE164 = typeof to === "string" && to.startsWith("+");
        logger.info("[minuteCron] about to send", {
          uid,
          hasMSID: !!msid,
          hasFROM: !!from,
          toLooksE164,
          bodyLen: body.length,
        });

        const msgParams = buildMsgParams({ to, body, from, msid });

        // ⚠️ Try to send; catch STOP here too
        let res: any;
        try {
          res = await sendSMS(client, msgParams);
        } catch (err: any) {
          if (isTwilioStopError(err)) {
            await applyOptOut(uid);
            logger.warn("[minuteCron] STOP detected (throw) → set inactive", { uid });
            continue;
          }
          // rethrow to hit outer catch for other errors
          throw err;
        }

        // ⚠️ If Twilio returned a Message but it’s already failed with STOP
        const resCode = res?.errorCode != null ? String(res.errorCode) : "";
        const resFailed =
          resCode === "21610" ||
          (typeof res?.status === "string" && res.status.toLowerCase() === "failed");

        if (resFailed) {
          await applyOptOut(uid);
          logger.warn("[minuteCron] STOP detected (message response) → set inactive", {
            uid,
            status: res?.status,
            errorCode: res?.errorCode,
          });
          continue;
        }

        // ✅ Success: reflect that the number is currently allowed (after START/UNSTOP)
        await db.doc(`users/${uid}`).set({ active: true, smsOptOut: false }, { merge: true });

        logger.info("[minuteCron] sent", { uid, sid: res?.sid });

        // 4) Reschedule next (still respects ≥10 entries)
        await scheduleNext(uid, new Date());
      } catch (e: any) {
        // String-only error log so the logger never throws and the summary shows details
        const details = {
          uid,
          message: e?.message ?? String(e),
          code: e?.code ?? null,
          status: e?.status ?? null,
          moreInfo: e?.moreInfo ?? null,
        };
        logger.error("[minuteCron] send failed details " + JSON.stringify(details));

        // advance to avoid tight loops on other errors
        await scheduleNext(uid, new Date());
      }
    }
  }
);

// ---------- ✅ auto-start scheduling when the 10th entry is added ----------
export const onEntryCreated = onDocumentCreated(
  "users/{uid}/entries/{entryId}",
  async (event) => {
    const uid = event.params.uid as string;

    // Only act for active users
    const user = await db.doc(`users/${uid}`).get();
    if (!user.exists || user.get("active") !== true) return;

    // If they just hit the threshold, schedule their first/next send
    if (await hasAtLeastEntries(uid, 10)) {
      await scheduleNext(uid, new Date());
    }
  }
);

// ---------- Twilio webhooks ----------

async function handleStopForPhone(phone: string) {
  const userDoc = await findUserByPhone(phone);
  if (!userDoc) {
    logger.warn("[twilioWebhook] STOP received but no user matched", { phone });
    return false;
  }
  await applyOptOut(userDoc.id);
  logger.warn("[twilioWebhook] user opted out", { uid: userDoc.id, phone });
  return true;
}

async function handleStartForPhone(phone: string) {
  const userDoc = await findUserByPhone(phone);
  if (!userDoc) {
    logger.warn("[twilioWebhook] START received but no user matched", { phone });
    return false;
  }
  await applyOptIn(userDoc.id);
  logger.info("[twilioWebhook] user re-subscribed", { uid: userDoc.id, phone });
  return true;
}

export const twilioStatusCallback = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const payload = parseTwilioPayload(req);
  const to = (payload.To || payload.to || "").toString();
  const errorCode = (payload.ErrorCode || payload.errorCode || "").toString();

  if (errorCode === "21610" && to) {
    await handleStopForPhone(to);
  }

  res.status(200).send("OK");
});

export const twilioInboundSms = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const payload = parseTwilioPayload(req);
  const from = (payload.From || payload.from || "").toString();
  const body = (payload.Body || payload.body || "").toString();

  if (!from) {
    res.status(200).set("Content-Type", "text/xml").send("<Response></Response>");
    return;
  }

  const keyword = normalizeKeyword(body);
  let message: string | null = null;
  let handled = false;

  if (STOP_KEYWORDS.has(keyword)) {
    handled = await handleStopForPhone(from);
    message = "You have been unsubscribed from ReMind messages.";
  } else if (START_KEYWORDS.has(keyword)) {
    handled = await handleStartForPhone(from);
    message = "You have been re-subscribed to ReMind messages.";
  }

  const responseBody =
    handled && message
      ? `<Response><Message>${escapeXml(message)}</Message></Response>`
      : "<Response></Response>";

  res.status(200).set("Content-Type", "text/xml").send(responseBody);
});