// ============================
// File: functions/src/user/sendOneNow.ts
// ============================
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  db,
  logger,
  applyOptOut,
  isTwilioStopError,
  TWILIO_SID,
  TWILIO_AUTH,
  TWILIO_FROM,
  TWILIO_MSID,
} from "../config/options";
import { getTwilioClient, buildMsgParams, sendSMS } from "../twilio/client";

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

      const sid = TWILIO_SID.value();
      const token = TWILIO_AUTH.value();
      const from = TWILIO_FROM.value();
      const msid = TWILIO_MSID.value();

      const client = getTwilioClient(sid, token);
      const msgParams = buildMsgParams({ to, body: text, from, msid });
      const res = await sendSMS(client, msgParams);

      logger.info("[sendOneNow] sent", { messageSid: res.sid });

      await candidate.ref.update({
        sent: true,
        sentAt: (await import("firebase-admin")).firestore.FieldValue.serverTimestamp(),
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
      throw new HttpsError("internal", err?.message ?? "Unknown error");
    }
  }
);
