// ============================
// File: functions/src/index.ts
// ============================

// ensure global options + admin init + secrets are registered
import "./config/options";

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
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


function resolveCommentId(data: Record<string, unknown> | undefined): string {
  const candidates = [data?.commentId, data?.replyId, data?.subCommentId];
  for (const raw of candidates) {
    if (typeof raw === "string" && raw.trim().length > 0) {
      return raw.trim();
    }
  }
  return "";
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

  const postRef = await db.collection("communityPosts").add({
    text,
    authorId: uid,
    createdAt: now,
    expiresAt,
    likeCount: 0,
    reportCount: 0,
    commentCount: 0,
    isHidden: false,
  });

  return {
    ok: true,
    post: {
      id: postRef.id,
      text,
      authorId: uid,
      createdAtMillis: now.toMillis(),
      expiresAtMillis: expiresAt.toMillis(),
      likeCount: 0,
      reportCount: 0,
      commentCount: 0,
      isHidden: false,
    },
  };
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

export const createCommunityComment = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to reply.");
  }

  const postId = (request.data?.postId ?? "") as string;
  if (!postId) {
    throw new HttpsError("invalid-argument", "A postId is required.");
  }

  const textRaw = (request.data?.text ?? "") as string;
  const text = textRaw.trim();
  if (!text) {
    throw new HttpsError("invalid-argument", "Reply text is required.");
  }
  if (text.length > 500) {
    throw new HttpsError(
      "invalid-argument",
      "Reply must be ≤ 500 characters."
    );
  }

  const postRef = db.collection("communityPosts").doc(postId);
  const commentRef = postRef.collection("comments").doc();

  return await db.runTransaction(async (tx) => {
    const postSnap = await tx.get(postRef);
    if (!postSnap.exists) {
      throw new HttpsError("not-found", "Post not found.");
    }

    const now = Timestamp.now();
    const currentCount = (postSnap.data()?.commentCount ?? 0) as number;

    tx.set(commentRef, {
      authorId: uid,
      text,
      createdAt: now,
      likeCount: 0,
      reportCount: 0,
      isHidden: false,
    });
    tx.update(postRef, {
      commentCount: currentCount + 1,
    });

    return { ok: true };
  });
});

export const toggleCommunityCommentLike = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to like replies.");
  }

  const postId = (request.data?.postId ?? "") as string;
  const commentId = resolveCommentId(request.data as Record<string, unknown> | undefined);
  if (!postId || !commentId) {
    logger.error("toggleCommunityCommentLike invalid arguments", {
      uid,
      postId,
      payloadKeys: Object.keys((request.data ?? {}) as Record<string, unknown>),
    });
    throw new HttpsError("invalid-argument", "A postId and commentId are required.");
  }

  const godModeUser = isGodMode(request.auth);
  const commentRef = db
    .collection("communityPosts")
    .doc(postId)
    .collection("comments")
    .doc(commentId);

  return await db.runTransaction(async (tx) => {
    const commentSnap = await tx.get(commentRef);
    if (!commentSnap.exists) {
      logger.error("toggleCommunityCommentLike missing comment", { uid, postId, commentId });
      throw new HttpsError("not-found", "Reply not found.");
    }

    const currentCount = (commentSnap.data()?.likeCount ?? 0) as number;
    if (godModeUser) {
      const nextCount = currentCount + 1;
      tx.update(commentRef, { likeCount: nextCount });
      return { liked: true, likeCount: nextCount, godMode: true };
    }

    const likeRef = commentRef.collection("likes").doc(uid);
    const likeSnap = await tx.get(likeRef);
    const alreadyLiked = likeSnap.exists;

    const nextCount = alreadyLiked
      ? Math.max(0, currentCount - 1)
      : currentCount + 1;

    if (alreadyLiked) {
      tx.delete(likeRef);
    } else {
      tx.set(likeRef, { createdAt: Timestamp.now() });
    }

    tx.update(commentRef, { likeCount: nextCount });
    return { liked: !alreadyLiked, likeCount: nextCount };
  });
});

export const toggleCommunityCommentReport = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to report replies.");
  }

  const postId = (request.data?.postId ?? "") as string;
  const commentId = resolveCommentId(request.data as Record<string, unknown> | undefined);
  if (!postId || !commentId) {
    logger.error("toggleCommunityCommentReport invalid arguments", {
      uid,
      postId,
      payloadKeys: Object.keys((request.data ?? {}) as Record<string, unknown>),
    });
    throw new HttpsError("invalid-argument", "A postId and commentId are required.");
  }

  const now = Timestamp.now();
  const godModeUser = isGodMode(request.auth);
  const limiterRef = db.collection("communityReportLimits").doc(uid);
  const commentRef = db
    .collection("communityPosts")
    .doc(postId)
    .collection("comments")
    .doc(commentId);

  return await db.runTransaction(async (tx) => {
    const commentSnap = await tx.get(commentRef);
    if (!commentSnap.exists) {
      logger.error("toggleCommunityCommentReport missing comment", { uid, postId, commentId });
      throw new HttpsError("not-found", "Reply not found.");
    }

    const currentCount = (commentSnap.data()?.reportCount ?? 0) as number;
    const alreadyHidden = Boolean(commentSnap.data()?.isHidden);

    if (godModeUser) {
      const nextCount = currentCount + 1;
      const updates: Record<string, unknown> = { reportCount: nextCount };
      if (nextCount >= 5 && !alreadyHidden) {
        updates["isHidden"] = true;
        updates["hiddenReason"] = "reports";
        updates["hiddenAt"] = Timestamp.now();
      }
      tx.update(commentRef, updates);
      return {
        reported: true,
        reportCount: nextCount,
        removed: Boolean(updates["isHidden"] ?? alreadyHidden),
        godMode: true,
      };
    }

    const reportRef = commentRef.collection("flags").doc(uid);
    const reportSnap = await tx.get(reportRef);
    const alreadyReported = reportSnap.exists;

    if (!alreadyReported) {
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
      tx.set(
        limiterRef,
        { recentReports: recentReports.slice(-REPORT_LIMIT_PER_HOUR) },
        { merge: true }
      );
    } else {
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
      tx.delete(reportRef);
    } else {
      tx.set(reportRef, { createdAt: now });
    }

    const updates: Record<string, unknown> = {
      reportCount: nextCount,
    };

    if (!alreadyReported && nextCount >= 5 && !alreadyHidden) {
      updates["isHidden"] = true;
      updates["hiddenReason"] = "reports";
      updates["hiddenAt"] = Timestamp.now();
    }

    tx.update(commentRef, updates);
    return {
      reported: !alreadyReported,
      reportCount: nextCount,
      removed: Boolean(updates["isHidden"] ?? alreadyHidden),
    };
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
export { recordAppActivity } from "./inactivity/recordAppActivity";

// onboarding
export { triggerWelcome } from "./onboarding/triggerWelcome";

// scheduler
export { minuteCron } from "./scheduler/minuteCron";
export { reconcileRevenueCatEntitlements } from "./scheduler/reconcileRevenueCatEntitlements";

// firestore triggers
export { onEntryCreated } from "./entries/onEntryCreated";

// twilio webhooks
export { twilioInboundSms, twilioStatusCallback } from "./twilio/webhooks";

// revenuecat webhook
export { revenueCatWebhook } from "./revenuecat/webhook";

// export - get URL
export { getExportUploadUrl } from "./exports/getExportUploadUrl";

// export - send link
export { sendExportLink } from "./exports/sendExportLink";
