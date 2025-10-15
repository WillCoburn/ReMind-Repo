// ============================
// File: functions/src/index.ts
// ============================

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import twilio from "twilio";

// ----- Global options (region) -----
setGlobalOptions({ region: "us-central1" });

// ----- Firebase init -----
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// ----- Secrets (recommended v2 API) -----
// Define once, then read with .value() *inside* your handler.
const TWILIO_SID = defineSecret("TWILIO_SID");
const TWILIO_AUTH = defineSecret("TWILIO_AUTH"); // use AUTH (common name)
const TWILIO_FROM = defineSecret("TWILIO_FROM");

// Helper: build Twilio client safely at runtime
function getTwilioClient(sid: string | undefined, auth: string | undefined) {
  if (!sid || !auth) {
    throw new Error("Twilio secrets not set (TWILIO_SID/TWILIO_AUTH).");
  }
  return twilio(sid, auth);
}

// Callable: send ONE unsent affirmation immediately via SMS
export const sendOneNow = onCall(
  {
    secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM],
    invoker: "public", // or restrict via IAM if you prefer
  },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

    // 1) Get user's phone number
    const userSnap = await db.doc(`users/${uid}`).get();
    if (!userSnap.exists) throw new HttpsError("not-found", "User not found.");

    const to = userSnap.get("phoneE164") as string | undefined;
    if (!to) throw new HttpsError("failed-precondition", "No phone number on file.");

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
      throw new HttpsError("failed-precondition", "No unsent entries available.");
    }

    const text = (candidate.get("text") as string) || "(no text)";

    // 3) Twilio send (lazy init; secrets accessed via .value())
    const client = getTwilioClient(TWILIO_SID.value(), TWILIO_AUTH.value());
    const from = TWILIO_FROM.value();
    if (!from) throw new Error("TWILIO_FROM not set.");

    await client.messages.create({ to, from, body: text });

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
