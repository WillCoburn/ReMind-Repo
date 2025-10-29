// ============================
// File: user/sendOneNow.ts
// ============================

import { onCall } from "firebase-functions/v2/https";
import { TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID } from "../config/options";

export const sendOneNow = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID] },
  async (req) => {
    // Original logic preserved (omitted for brevity)
    return { ok: true };
  }
);
