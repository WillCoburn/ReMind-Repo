import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, logger, scheduleNext } from "../config/options";
import { shouldClearInactivityAutoPauseOnActivity } from "./policy";

export const recordAppActivity = onCall({ invoker: "public" }, async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const userRef = db.doc(`users/${uid}`);
  const now = admin.firestore.Timestamp.now();
  let resumed = false;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const update: Record<string, unknown> = {
      uid,
      lastSeenAt: now,
      updatedAt: now,
    };

    if (!snap.exists) {
      update.createdAt = now;
    }

    if (snap.exists && shouldClearInactivityAutoPauseOnActivity(snap)) {
      resumed = true;
      update.autoPausedAt = admin.firestore.FieldValue.delete();
      update.autoPauseReason = admin.firestore.FieldValue.delete();
      update.autoPauseNotifiedAt = admin.firestore.FieldValue.delete();
    }

    tx.set(userRef, update, { merge: true });
  });

  if (resumed) {
    await scheduleNext(uid, now.toDate());
    logger.info("[recordAppActivity] resumed inactivity auto-pause", { uid });
  }

  return { ok: true, resumed };
});
