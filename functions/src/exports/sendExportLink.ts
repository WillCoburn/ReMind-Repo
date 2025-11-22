// ============================
// File: functions/src/exports/sendExportLink.ts
// ============================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { randomUUID } from "node:crypto";
import {
  db,
  applyOptOut,
  isTwilioStopError,
  incrementReceivedCount,
  TWILIO_SID,
  TWILIO_AUTH,
  TWILIO_FROM,
  TWILIO_MSID,
} from "../config/options";
import { getTwilioClient, buildMsgParams, sendSMS } from "../twilio/client";
import { enforceMonthlyLimit } from "../usageLimits";

export const sendExportLink = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID] },
  async (req) => {
    const uid = req.auth?.uid || null;
    const path = String((req.data?.path ?? "")).trim();

    logger.info("[sendExportLink] start", { uid, path });

    try {
      if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
      if (!path || !path.startsWith(`users/${uid}/exports/`)) {
        throw new HttpsError("invalid-argument", "Invalid or unauthorized path.");
      }

      // 🔒 Enforce 20 PDF exports per 30-day window
      await enforceMonthlyLimit(uid, "pdfExportsThisMonth", 20);

      // 1) Ensure the file exists in the default bucket
      const bucket = admin.storage().bucket();
      const file = bucket.file(path);
      const [exists] = await file.exists();
      if (!exists) {
        throw new HttpsError(
          "not-found",
          "Export file not found. Upload may not have completed."
        );
      }

      // 2) Try to create a 7-day signed READ URL (preferred)
      let link: string | null = null;
      try {
        const [signedUrl] = await file.getSignedUrl({
          version: "v4",
          action: "read",
          expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
        });
        link = signedUrl;
        logger.info("[sendExportLink] generated signed read URL");
      } catch (signErr: any) {
        logger.warn("[sendExportLink] getSignedUrl failed, falling back to token link", {
          message: signErr?.message,
        });
      }

      // 3) Fallback: tokenized public link (if signing not available)
      if (!link) {
        const [meta] = await file.getMetadata();
        const tokensRaw = meta?.metadata?.firebaseStorageDownloadTokens as
          | string
          | undefined;
        let token =
          tokensRaw?.split(",").map((s) => s.trim()).filter(Boolean)[0] ||
          randomUUID();

        if (!tokensRaw) {
          await file.setMetadata({
            metadata: { firebaseStorageDownloadTokens: token },
          });
        }

        const encodedPath = encodeURIComponent(path);
        link = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${token}`;
        logger.info("[sendExportLink] generated token-based download URL");
      }

      // 4) Lookup recipient phone
      const userSnap = await db.doc(`users/${uid}`).get();
      const to = (userSnap.get("phoneE164") as string | undefined) || null;
      if (!to) {
        throw new HttpsError(
          "failed-precondition",
          "No phone number on file for user."
        );
      }

      // 5) Send SMS via Twilio
      const sid = TWILIO_SID.value();
      const auth = TWILIO_AUTH.value();
      const from = TWILIO_FROM.value();
      const msid = TWILIO_MSID.value();
      const client = getTwilioClient(sid, auth);

      const body = `Here’s your ReMind PDF export: ${link} (expires in 7 days).`;
      const msgParams = buildMsgParams({ to, body, from, msid });
      let messageSid: string | undefined;

      try {
        const res = await sendSMS(client, msgParams);
        messageSid = res.sid;
        logger.info("[sendExportLink] SMS sent", { messageSid });
      } catch (twilioErr: any) {
        // Handle STOP/opt-out gracefully
        if (isTwilioStopError(twilioErr)) {
          await applyOptOut(uid);
          logger.warn("[sendExportLink] recipient opted out; user deactivated", { uid });
        }

        const details = {
          provider: "twilio",
          status: twilioErr?.status,
          code: twilioErr?.code,
          moreInfo: twilioErr?.moreInfo,
          message: twilioErr?.message,
        };
        logger.error("[sendExportLink] Twilio error", details);
        throw new HttpsError(
          "failed-precondition",
          `Twilio ${details.code ?? ""} ${
            details.message ?? "send failed"
          }`.trim(),
          details
        );
      }

      // 6) (Optional) You could record an export log here if desired.
      try {
        await incrementReceivedCount(uid);
      } catch (metricErr: any) {
        logger.warn("[sendExportLink] failed to increment receivedCount", {
          uid,
          message: metricErr?.message,
        });
      }

      return { ok: true, path, link, messageSid };
    } catch (e: any) {
      // Surface typed HttpsError if thrown (including the cap); otherwise wrap as internal
      if (e instanceof HttpsError) throw e;
      logger.error("[sendExportLink] failed", {
        uid,
        path,
        message: e?.message,
        stack: e?.stack,
      });
      throw new HttpsError("internal", e?.message ?? "Internal error");
    }
  }
);
