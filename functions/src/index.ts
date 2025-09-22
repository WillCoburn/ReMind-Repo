// ============================
// File: functions/src/index.ts
// ============================

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";
import Twilio from "twilio";

const REGION = "us-central1";

// We will read env vars and init Twilio **inside** the handler to avoid
// "username is required" during Firebase's code analysis phase.

// ----- Firebase init -----
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// Helper: build Twilio client safely at runtime
function getTwilio() {
  const sid = process.env.TWILIO_SID;
  const token = process.env.TWILIO_TOKEN;
  if (!sid || !token) {
    throw new Error("Twilio secrets not set (TWILIO_SID/TWILIO_TOKEN).");
  }
  return Twilio(sid, token);
}

// Helper: get FROM number from env
function getFromNumber() {
  const from = process.env.TWILIO_FROM;
  if (!from) throw new Error("Twilio FROM number not set (TWILIO_FROM).");
  return from;
}

/**
 * Callable Cloud Function: send ONE unsent affirmation immediately via SMS.
 * - Reads /users/{uid}/entries ordered by createdAt (oldest first)
 * - Finds the first "unsent" item (sentAt missing/null and sent != true)
 * - Sends SMS via Twilio
 * - Marks the entry as sent
 */
export const sendOneNow = onCall(
  { region: REGION, secrets: ["TWILIO_SID", "TWILIO_TOKEN", "TWILIO_FROM"] },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
    }

    // 1) Get user's phone number (+E.164) from Firestore
    const userSnap = await db.doc(`users/${uid}`).get();
    if (!userSnap.exists) {
      throw new functions.https.HttpsError("not-found", "User not found.");
    }
    const to = userSnap.get("phoneE164") as string | undefined;
    if (!to) {
      throw new functions.https.HttpsError("failed-precondition", "No phone number on file.");
    }

    // 2) Find one unsent affirmation (oldest first)
    const qs = await db
      .collection(`users/${uid}/entries`)
      .orderBy("createdAt", "asc")
      .limit(25)
      .get();

    const candidate = qs.docs.find((d) => {
      const data = d.data() as any;
      const sentAtMissingOrNull = !("sentAt" in data) || data.sentAt === null;
      const sentNotTrue = data.sent !== true;
      return sentAtMissingOrNull && sentNotTrue;
    });

    if (!candidate) {
      throw new functions.https.HttpsError("failed-precondition", "No unsent entries available.");
    }

    const text = (candidate.get("text") as string) || "(no text)";

    // 3) Send SMS via Twilio (initialized lazily here)
    const twilio = getTwilio();
    await twilio.messages.create({
      to,
      from: getFromNumber(),
      body: text,
    });

    // 4) Mark as sent
    await candidate.ref.update({
      sent: true,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      deliveredVia: "sms",
      scheduledFor: null,
    });

    return { ok: true, entryId: candidate.id };
  }
);

