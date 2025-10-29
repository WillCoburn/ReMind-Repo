// ============================
// File: functions/src/user/applyUserSettings.ts
// ============================
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { scheduleNext, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID, TWILIO_SID } from "../config/options";

export const applyUserSettings = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID], invoker: "public" },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
    await scheduleNext(uid, new Date());
    return { ok: true };
  }
);
