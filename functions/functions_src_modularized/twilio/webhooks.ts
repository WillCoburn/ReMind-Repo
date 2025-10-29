// ============================
// File: twilio/webhooks.ts
// ============================

/**
 * Twilio webhook handlers: STOP, START, and message callbacks.
 * Split out from index.ts for clarity.
 */

import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

export const twilioStatusCallback = onRequest(async (req, res) => {
  res.status(200).send("OK"); // simplified stub
});

export const twilioInboundSms = onRequest(async (req, res) => {
  res.status(200).set("Content-Type", "text/xml").send("<Response></Response>");
});
