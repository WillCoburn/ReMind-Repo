// ============================
// File: functions/src/user/sendOneNow.ts
// ============================
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  admin,
  db,
  logger,
  applyOptOut,
  isTwilioStopError,
  pickEntry,
  incrementReceivedCount,
  TWILIO_SID,
  TWILIO_AUTH,
  TWILIO_FROM,
  TWILIO_MSID,
} from "../config/options";
import { getTwilioClient, buildMsgParams, sendSMS } from "../twilio/client";
import { enforceMonthlyLimit } from "../usageLimits";

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

      // 🔒 Enforce 50 manual sends per 30-day window
      await enforceMonthlyLimit(uid, "manualSendsThisMonth", 50);

      // Get recipient phone
      const userSnap = await db.doc(`users/${uid}`).get();
      if (!userSnap.exists) throw new HttpsError("not-found", "User not found.");
      const to = userSnap.get("phoneE164") as string | undefined;
      if (!to) throw new HttpsError("failed-precondition", "No phone number on file.");

      // Pick entry
      const picked = await pickEntry(uid);
      const body = picked?.body;
      if (!body) throw new HttpsError("failed-precondition", "No entries available.");

      // Send via Twilio
      const sid = TWILIO_SID.value();
      const token = TWILIO_AUTH.value();
      const from = TWILIO_FROM.value();
      const msid = TWILIO_MSID.value();
      const client = getTwilioClient(sid, token);

      const params = buildMsgParams({ to, body, from, msid });
      const res = await sendSMS(client, params);
      logger.info("[sendOneNow] sent", { messageSid: res.sid });

      // Mark matching unsent entry as sent (best-effort)
      try {
        if (picked?.ref) {
          await picked.ref.update({
            sent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            deliveredVia: "sms",
            scheduledFor: null,
          });
        } else {
          logger.info("[sendOneNow] no matching unsent entry to mark as sent", { uid });
        }
      } catch (markErr: any) {
        logger.warn("[sendOneNow] failed to mark entry sent", {
          uid,
          message: markErr?.message,
        });
      }

      try {
        await incrementReceivedCount(uid);
      } catch (metricErr: any) {
        logger.warn("[sendOneNow] failed to increment receivedCount", {
          uid,
          message: metricErr?.message,
        });
      }

      return { ok: true, messageSid: res.sid };
    } catch (err: any) {
      if (err instanceof HttpsError) {
        throw err;
      }
      if (isTwilioStopError(err)) {
        const uid = req.auth?.uid as string | undefined;
        if (uid) await applyOptOut(uid);
      }
      if (err?.moreInfo || err?.code || err?.status) throw twilioHttpsError(err);
      throw new HttpsError("internal", err?.message ?? "Unknown error");
    }
  }
);
