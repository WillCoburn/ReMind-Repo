// ============================
// File: exports/getExportUploadUrl.ts
// ============================

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/** Returns a signed URL allowing the client to PUT a PDF to a Storage path */
export const getExportUploadUrl = onCall({}, async (req) => {
  const uid = req.auth?.uid || null;
  const path = String((req.data?.path ?? "")).trim();
  const contentType = String(req.data?.contentType ?? "application/pdf");

  logger.info("getExportUploadUrl start", { uid, path, contentType });

  if (!uid) throw new HttpsError("unauthenticated", "Signin required");
  if (!path.startsWith(`users/${uid}/exports/`))
    throw new HttpsError("invalid-argument", "Invalid path");

  const bucket = admin.storage().bucket();
  const file = bucket.file(path);
  const [url] = await file.getSignedUrl({
    version: "v4",
    action: "write",
    expires: Date.now() + 15 * 60 * 1000,
    contentType,
  });

  logger.info("getExportUploadUrl success", { uid, path });
  return { uploadUrl: url, path };
});
