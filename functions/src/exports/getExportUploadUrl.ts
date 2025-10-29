// ============================
// File: exports/getExportUploadUrl.ts
// ============================

import "../config/options"; // 👈 ensures admin.initializeApp() + global options are applied

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/** Returns a signed URL allowing the client to PUT a PDF to a Storage path */
export const getExportUploadUrl = onCall({}, async (req) => {
  const uid = req.auth?.uid || null;
  const path = String((req.data?.path ?? "")).trim();
  const contentType = String(req.data?.contentType ?? "application/pdf");

  logger.info("getExportUploadUrl start", { uid, path, contentType });

  try {
    if (!uid) throw new HttpsError("unauthenticated", "Signin required");
    if (!path || !path.startsWith(`users/${uid}/exports/`)) {
      throw new HttpsError("invalid-argument", "Invalid path");
    }

    const bucket = admin.storage().bucket(); // requires admin.initializeApp() to have run
    const file = bucket.file(path);

    // 15 minutes to upload
    const [url] = await file.getSignedUrl({
      version: "v4",
      action: "write",
      expires: Date.now() + 15 * 60 * 1000,
      contentType,
    });

    logger.info("getExportUploadUrl success", { uid, path });
    return { uploadUrl: url, path };
  } catch (e: any) {
    logger.error("getExportUploadUrl failed", {
      uid,
      path,
      err: e?.message ?? String(e),
      stack: e?.stack,
    });
    // If caller sent a typed HttpsError (e.g., invalid-argument), preserve it; else wrap as internal
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", e?.message ?? "internal");
  }
});
