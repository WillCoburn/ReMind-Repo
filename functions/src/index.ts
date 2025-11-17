// ============================
// File: functions/src/index.ts
// ============================

// ensure global options + admin init + secrets are registered
import "./config/options";

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "./config/options";

// -----------------------------
// community: createCommunityPost
// -----------------------------
export const createCommunityPost = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to post.");
  }

  const textRaw = (request.data?.text ?? "") as string;
  const text = textRaw.trim();

  if (!text) {
    throw new HttpsError("invalid-argument", "Post text is required.");
  }
  if (text.length > 500) {
    throw new HttpsError(
      "invalid-argument",
      "Post must be ≤ 500 characters."
    );
  }

  const now = Timestamp.now();
  const oneDayAgo = Timestamp.fromMillis(now.toMillis() - 24 * 60 * 60 * 1000);

  // 1 post per user per 24h
  const recentSnap = await db
    .collection("communityPosts")
    .where("authorId", "==", uid)
    .where("createdAt", ">", oneDayAgo)
    .limit(1)
    .get();

  if (!recentSnap.empty) {
    throw new HttpsError(
      "failed-precondition",
      "You can only post once per day."
    );
  }

  const expiresAt = Timestamp.fromMillis(
    now.toMillis() + 7 * 24 * 60 * 60 * 1000
  ); // 7 days

  await db.collection("communityPosts").add({
    text,
    authorId: uid,
    createdAt: now,
    expiresAt,
    likeCount: 0,
    reportCount: 0,
    isHidden: false,
  });

  return { ok: true };
});

// -----------------------------
// existing exports
// -----------------------------

// callables (user)
export { sendOneNow } from "./user/sendOneNow";
export { applyUserSettings } from "./user/applyUserSettings";

// onboarding
export { triggerWelcome } from "./onboarding/triggerWelcome";

// scheduler
export { minuteCron } from "./scheduler/minuteCron";

// firestore triggers
export { onEntryCreated } from "./entries/onEntryCreated";

// twilio webhooks
export { twilioInboundSms, twilioStatusCallback } from "./twilio/webhooks";

// export - get URL
export { getExportUploadUrl } from "./exports/getExportUploadUrl";

// export - send link
export { sendExportLink } from "./exports/sendExportLink";
