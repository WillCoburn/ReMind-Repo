// ============================
// File: functions/src/onboarding/triggerWelcome.ts
// ============================
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  admin,
  db,
  logger,
  scheduleNext,
  applyOptOut,
  isTwilioStopError,
  TWILIO_SID,
  TWILIO_AUTH,
  TWILIO_FROM,
  TWILIO_MSID,
} from "../config/options";
import { getTwilioClient, buildMsgParams } from "../twilio/client";

const WELCOME_TEXT = "Welcome to ReMind! Reply STOP to opt out or HELP for help.";

async function getUserPhoneE164(uid: string): Promise<string | null> {
  const userDoc = await db.doc(`users/${uid}`).get();
  const fsPhone =
    (userDoc.get("phoneE164") as string | undefined) ||
    (userDoc.get("phone") as string | undefined) ||
    null;

  if (fsPhone && /^(\+)[1-9]\d{1,14}$/.test(fsPhone)) return fsPhone;

  try {
    const authUser = await admin.auth().getUser(uid);
    const authPhone = authUser.phoneNumber || null;
    if (authPhone && /^(\+)[1-9]\d{1,14}$/.test(authPhone)) {
      await db.doc(`users/${uid}`).set({ phoneE164: authPhone }, { merge: true });
      return authPhone;
    }
  } catch (e: any) {
    logger.warn("[getUserPhoneE164] auth lookup failed", { uid, message: e?.message });
  }
  return null;
}

async function sendWelcomeIfNeeded(
  uid: string,
  to: string,
  client: ReturnType<typeof getTwilioClient>,
  from?: string | null,
  msid?: string | null
) {
  const userRef = db.doc(`users/${uid}`);
  const snap = await userRef.get();
  const already = snap.get("welcomed") === true;
  if (already) return false;

  const params = buildMsgParams({ to, body: WELCOME_TEXT, from: from ?? null, msid: msid ?? null });

  let res: any;
  try {
    res = await (client as any).messages.create(params as any);
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

export const triggerWelcome = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID], invoker: "public" },
  async (req) => {
    const callerUid = req.auth?.uid as string | undefined;
    const targetUid = (req.data?.uid as string | undefined) || callerUid;
    if (!targetUid) throw new HttpsError("unauthenticated", "Sign in or provide data.uid.");

    const sid = TWILIO_SID.value();
    const token = TWILIO_AUTH.value();
    const from = TWILIO_FROM.value();
    const msid = TWILIO_MSID.value();
    const client = getTwilioClient(sid, token);

    await db.doc(`users/${targetUid}`).set({ active: true, smsOptOut: false }, { merge: true });
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
      if (sent) await scheduleNext(targetUid, new Date());
      logger.info("[triggerWelcome] done", { uid: targetUid, sent });
      return { ok: true, sent };
    } catch (err: any) {
      if (isTwilioStopError(err)) await applyOptOut(targetUid);

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
