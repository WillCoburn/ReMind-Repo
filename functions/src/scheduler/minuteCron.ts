// ============================
// File: scheduler/minuteCron.ts
// ============================

/**
 * Runs every minute to deliver queued reminders and schedule the next send.
 * This is one of the most complex parts of the app, but we keep logic identical.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID } from "../config/options";
import { getTwilioClient } from "../twilio/client";

export const minuteCron = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "UTC",
    secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID],
  },
  async () => {
    logger.info("[minuteCron] boot v1");
    // Original logic will go here (omitted for brevity)
  }
);
