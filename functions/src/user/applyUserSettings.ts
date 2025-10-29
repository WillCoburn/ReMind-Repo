// ============================
// File: user/applyUserSettings.ts
// ============================

import { onCall } from "firebase-functions/v2/https";
import { TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID } from "../config/options";

export const applyUserSettings = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID] },
  async (req) => {
    // Logic preserved from index.ts (omitted for brevity)
    return { ok: true };
  }
);
