// ============================
// File: functions/src/index.ts
// ============================

// ensure global options + admin init + secrets are registered
import "./config/options";

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "./config/options";
import { isGodMode } from "./config/godMode";

const REPORT_LIMIT_PER_HOUR = 5;
const REPORT_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const REPORT_LIMIT_MESSAGE =
  "Reports are limited to 5 per hour to avoid report-spamming.";

const COMMUNITY_POST_LIMIT_PER_DAY = 5;

interface CommunityReportLimitDoc {
  recentReports?: Timestamp[];
}

// -----------------------------
// community: createCommunityPost
// -----------------------------
export const createCommunityPost = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to post.");
  }

  const godModeUser = isGodMode(request.auth);

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

  if (!godModeUser) {
    // 5 post per user per 24h
    const recentSnap = await db
      .collection("communityPosts")
      .where("authorId", "==", uid)
      .where("createdAt", ">", oneDayAgo)
      .limit(COMMUNITY_POST_LIMIT_PER_DAY)
      .get();

    if (recentSnap.size >= COMMUNITY_POST_LIMIT_PER_DAY) {
      throw new HttpsError(
        "failed-precondition",
        "You can post up to 5 times per day."
      );
    }
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

export const toggleCommunityLike = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to like posts.");
  }

  const godModeUser = isGodMode(request.auth);

  const postId = (request.data?.postId ?? "") as string;
  if (!postId) {
    throw new HttpsError("invalid-argument", "A postId is required.");
  }

  const postRef = db.collection("communityPosts").doc(postId);

  return await db.runTransaction(async (tx) => {
    const postSnap = await tx.get(postRef);
    if (!postSnap.exists) {
      throw new HttpsError("not-found", "Post not found.");
    }

    const currentCount = (postSnap.data()?.likeCount ?? 0) as number;
    if (godModeUser) {
      const nextCount = currentCount + 1;
      tx.update(postRef, { likeCount: nextCount });
      return { liked: true, likeCount: nextCount, godMode: true };
    }

    const likeDocRef = postRef.collection("likes").doc(uid);
    const likeSnap = await tx.get(likeDocRef);
    const alreadyLiked = likeSnap.exists;

    const nextCount = alreadyLiked
      ? Math.max(0, currentCount - 1)
      : currentCount + 1;

    if (alreadyLiked) {
      tx.delete(likeDocRef);
    } else {
      tx.set(likeDocRef, { createdAt: Timestamp.now() });
    }

    tx.update(postRef, {
      likeCount: nextCount,
    });

    return { liked: !alreadyLiked, likeCount: nextCount };
  });
});

export const toggleCommunityReport = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to report posts.");
  }

  const postId = (request.data?.postId ?? "") as string;
  if (!postId) {
    throw new HttpsError("invalid-argument", "A postId is required.");
  }

  const postRef = db.collection("communityPosts").doc(postId);
  const limiterRef = db.collection("communityReportLimits").doc(uid);
  const godModeUser = isGodMode(request.auth);

  return await db.runTransaction(async (tx) => {
    const now = Timestamp.now();
    const postSnap = await tx.get(postRef);
    if (!postSnap.exists) {
      throw new HttpsError("not-found", "Post not found.");
    }

    const currentCount = (postSnap.data()?.reportCount ?? 0) as number;
    const alreadyHidden = Boolean(postSnap.data()?.isHidden);

    if (godModeUser) {
      const nextCount = currentCount + 1;
      const updates: Record<string, unknown> = { reportCount: nextCount };

      if (nextCount >= 5 && !alreadyHidden) {
        updates["isHidden"] = true;
        updates["hiddenReason"] = "reports";
        updates["hiddenAt"] = Timestamp.now();
      }

      tx.update(postRef, updates);
      return {
        reported: true,
        reportCount: nextCount,
        removed: Boolean(updates["isHidden"] ?? alreadyHidden),
        godMode: true,
      };
    }

    const reportDocRef = postRef.collection("reports").doc(uid);
    const reportSnap = await tx.get(reportDocRef);
    const alreadyReported = reportSnap.exists;

    if (!godModeUser && !alreadyReported) {
      const limiterSnap = await tx.get(limiterRef);
      const limiterData = limiterSnap.data() as
        | CommunityReportLimitDoc
        | undefined;
      const cutoffMillis = now.toMillis() - REPORT_LIMIT_WINDOW_MS;
      let recentReports = (limiterData?.recentReports ?? []).filter(
        (entry): entry is Timestamp => entry instanceof Timestamp
      );
      recentReports = recentReports.filter(
        (entry) => entry.toMillis() > cutoffMillis
      );

      if (recentReports.length >= REPORT_LIMIT_PER_HOUR) {
        throw new HttpsError(
          "resource-exhausted",
          REPORT_LIMIT_MESSAGE,
          REPORT_LIMIT_MESSAGE
        );
      }

      recentReports.push(now);
      const trimmedReports = recentReports.slice(-REPORT_LIMIT_PER_HOUR);

      tx.set(
        limiterRef,
        { recentReports: trimmedReports },
        { merge: true }
      );
    } else if (!godModeUser) {
      // Keep the limiter document tidy even when the user un-reports.
      const limiterSnap = await tx.get(limiterRef);
      if (limiterSnap.exists) {
        const limiterData = limiterSnap.data() as CommunityReportLimitDoc;
        const cutoffMillis = now.toMillis() - REPORT_LIMIT_WINDOW_MS;
        const trimmedReports = (limiterData.recentReports ?? [])
          .filter((entry): entry is Timestamp => entry instanceof Timestamp)
          .filter((entry) => entry.toMillis() > cutoffMillis)
          .slice(-REPORT_LIMIT_PER_HOUR);

        tx.set(
          limiterRef,
          { recentReports: trimmedReports },
          { merge: true }
        );
      }
    }

    const nextCount = alreadyReported
      ? Math.max(0, currentCount - 1)
      : currentCount + 1;

    if (alreadyReported) {
      tx.delete(reportDocRef);
    } else {
      tx.set(reportDocRef, { createdAt: now });
    }

    const updates: Record<string, unknown> = {
      reportCount: nextCount,
    };

    if (!alreadyReported && nextCount >= 5 && !alreadyHidden) {
      updates["isHidden"] = true;
      updates["hiddenReason"] = "reports";
      updates["hiddenAt"] = Timestamp.now();
    }

    tx.update(postRef, updates);

    return {
      reported: !alreadyReported,
      reportCount: nextCount,
      removed: Boolean(updates["isHidden"] ?? alreadyHidden),
    };
  });
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
