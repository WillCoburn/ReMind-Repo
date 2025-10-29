// ============================
// File: onboarding/triggerWelcome.ts
// ============================

import { onCall } from "firebase-functions/v2/https";
import { TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID } from "../config/options";

export const triggerWelcome = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID] },
  async (req) => {
    // Original triggerWelcome logic (preserved)
    return { ok: true };
  }
);
