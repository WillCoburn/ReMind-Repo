// ============================
// File: functions/src/index.ts
// ============================

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import twilio from "twilio";

// ----- Global options (region) -----
setGlobalOptions({ region: "us-central1" });

// ----- Firebase init -----
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// ----- Secrets (v2 API) -----
// Make sure these names match exactly what you created in Secret Manager.
const TWILIO_SID  = defineSecret("TWILIO_SID");   // e.g., ACxxxxxxxx...
const TWILIO_AUTH = defineSecret("TWILIO_AUTH");  // 32-char auth token
const TWILIO_FROM = defineSecret("TWILIO_FROM");  // "+1XXXXXXXXXX" (E.164)
// Optional but recommended: use a Messaging Service instead of raw FROM
const TWILIO_MSID = defineSecret("TWILIO_MSID");  // e.g., MGxxxxxxxx... (optional)

// Helper: build Twilio client safely at runtime
function getTwilioClient(sid?: string, auth?: string) {
  if (!sid || !auth) {
    throw new Error("Twilio secrets not set (TWILIO_SID/TWILIO_AUTH).");
  }
  return twilio(sid, auth);
}

// Small helper to surface useful, structured errors to the app (Approach #5)
function twilioHttpsError(err: any): HttpsError {
  // Twilio typically provides: err.status, err.code, err.moreInfo, err.message
  const details = {
    provider: "twilio",
    status: err?.status,
    code: err?.code,
    moreInfo: err?.moreInfo,
    message: err?.message,
  };
  logger.error("[sendOneNow] Twilio error", details);
  // failed-precondition is a good generic choice for external dependency errors
  return new HttpsError(
    "failed-precondition",
    `Twilio ${details.code ?? ""} ${details.message ?? "send failed"}`.trim(),
    details
  );
}

// Callable: send ONE unsent affirmation immediately via SMS
export const sendOneNow = onCall(
  {
    secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID],
    invoker: "public", // tighten via IAM if desired
  },
  async (req) => {
    try {
      const uid = req.auth?.uid;
      if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

      // 1) Get user's phone number
      const userSnap = await db.doc(`users/${uid}`).get();
      if (!userSnap.exists) throw new HttpsError("not-found", "User not found.");

      // Expect you stored E.164 in Firestore (e.g., "+16155551234")
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
        const noSentAt = !("sentAt" in data) || data.sentAt === null;
        const notMarkedSent = data.sent !== true;
        return noSentAt && notMarkedSent;
      });

      if (!candidate) {
        throw new HttpsError("failed-precondition", "No unsent entries available.");
      }

      const text = (candidate.get("text") as string) || "(no text)";

      // 3) Twilio send (with preflight diagnostics)
      const sid   = TWILIO_SID.value();
      const token = TWILIO_AUTH.value();
      const from  = TWILIO_FROM.value();
      const msid  = TWILIO_MSID.value(); // optional

      // Minimal, safe env logging (no secrets)
      logger.info("[sendOneNow] env", {
        sidPrefix: sid?.slice(0, 2),       // should be "AC"
        fromLen: from?.length,             // 12 for +1XXXXXXXXXX
        usingMSID: Boolean(msid),
        project: process.env.GCLOUD_PROJECT,
      });

      if (!sid || !token) throw new Error("Missing Twilio SID/AUTH.");
      if (!from && !msid) throw new Error("Configure TWILIO_FROM or TWILIO_MSID.");

      const client = getTwilioClient(sid, token);

      // --------- Preflight checks (Approach #1 diagnostics) ----------
      // A) Validate credentials (will 401/20003 if wrong)
      const acct = await client.api.accounts(sid).fetch();
      logger.info("[sendOneNow] account ok", { friendlyName: acct.friendlyName });

      // B) If sending with raw FROM, verify the number is owned by this account
      if (!msid && from) {
        const nums = await client.incomingPhoneNumbers.list({ phoneNumber: from, limit: 1 });
        logger.info("[sendOneNow] from owned?", { count: nums.length });
        if (nums.length === 0) {
          // Not owned by this account/subaccount; this is a classic 20003 cause
          throw new HttpsError("failed-precondition",
            "Configured FROM number is not owned by the authenticated Twilio account.",
            { provider: "twilio", from, accountSidChecked: sid });
        }
      }
      // ----------------------------------------------------------------

      // Build message params (prefer Messaging Service if present)
      const msgParams = msid
        ? { to, body: text, messagingServiceSid: msid }
        : { to, body: text, from: from! };

      const res = await client.messages.create(msgParams as any);
      logger.info("[sendOneNow] sent", { messageSid: res.sid });

      // 4) Mark as sent
      await candidate.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        deliveredVia: "sms",
        scheduledFor: null,
      });

      return { ok: true, entryId: candidate.id, messageSid: res.sid };
    } catch (err: any) {
      // Surface Twilio specifics if present; otherwise fallback
      if (err?.moreInfo || err?.code || err?.status) {
        throw twilioHttpsError(err); // rich details for iOS (Approach #5)
      }
      logger.error("[sendOneNow] unexpected error", { message: err?.message, stack: err?.stack });
      throw new HttpsError("internal", err?.message ?? "Unknown error");
    }
  }
);
