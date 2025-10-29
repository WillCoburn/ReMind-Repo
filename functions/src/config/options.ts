// ============================
// File: config/options.ts
// ============================

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";

// Global Firebase configuration
setGlobalOptions({ region: "us-central1" });

// Initialize Firebase Admin SDK (singleton)
if (admin.apps.length === 0) admin.initializeApp();
export const db = admin.firestore();

// Define Twilio secrets for all callable/scheduled functions
export const TWILIO_SID = defineSecret("TWILIO_SID");
export const TWILIO_AUTH = defineSecret("TWILIO_AUTH");
export const TWILIO_FROM = defineSecret("TWILIO_FROM");
export const TWILIO_MSID = defineSecret("TWILIO_MSID");
