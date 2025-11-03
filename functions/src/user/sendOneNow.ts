// ============================
// File: functions/src/user/sendOneNow.ts
// ============================
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  db,
  logger,
  applyOptOut,
  isTwilioStopError,
  pickEntry,                // 👈 use the shared randomized picker
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

      // Get recipient phone
      const userSnap = await db.doc(`users/${uid}`).get();
      if (!userSnap.exists) throw new HttpsError("not-found", "User not found.");
      const to = userSnap.get("phoneE164") as string | undefined;
      if (!to) throw new HttpsError("failed-precondition", "No phone number on file.");

      // 👇 Randomized pick that considers all entries (unsent preferred; fallback to any)
      const body = await pickEntry(uid);
      if (!body) throw new HttpsError("failed-precondition", "No entries available.");

      // Send via Twilio (Messaging Service SID if present, else From number)
      const sid = TWILIO_SID.value();
      const token = TWILIO_AUTH.value();
      const from = TWILIO_FROM.value();
      const msid = TWILIO_MSID.value();
      const client = getTwilioClient(sid, token);

      const params = buildMsgParams({ to, body, from, msid });
      const res = await sendSMS(client, params);
      logger.info("[sendOneNow] sent", { messageSid: res.sid });

      // ✅ Best-effort: mark the most recent UNSENT entry with the same text as sent
      // (If your entry schema uses a different field than "text", adjust here.)
      try {
        const match = await db
          .collection(`users/${uid}/entries`)
          .where("text", "==", body)
          .where("sent", "==", false)
          .orderBy("createdAt", "desc")
          .limit(1)
          .get();

        if (!match.empty) {
          await match.docs[0].ref.update({
            sent: true,
            sentAt: (await import("firebase-admin")).firestore.FieldValue.serverTimestamp(),
            deliveredVia: "sms",
            scheduledFor: null,
          });
        } else {
          // Nothing matched (maybe already marked, or text stored under a different key) — just log.
          logger.info("[sendOneNow] no matching unsent entry to mark as sent", { uid });
        }
      } catch (markErr: any) {
        logger.warn("[sendOneNow] failed to mark entry sent", { uid, message: markErr?.message });
      }

      return { ok: true, messageSid: res.sid };
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
