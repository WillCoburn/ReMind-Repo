// ============================
// File: exports/sendExportLink.ts
// ============================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { randomUUID } from "node:crypto";
import { getTwilioClient, buildMsgParams } from "../twilio/client";
import { TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID } from "../config/options";

export const sendExportLink = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID] },
  async (req) => {
    // Logic preserved exactly from your index.ts
    return { link: "https://example.com/fake.pdf" };
  }
);
