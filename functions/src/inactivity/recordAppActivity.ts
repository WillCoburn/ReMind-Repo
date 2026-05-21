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
    if (!snap.exists) throw new HttpsError("not-found", "User not found.");

    const update: Record<string, unknown> = {
      lastSeenAt: now,
    };

    if (shouldClearInactivityAutoPauseOnActivity(snap)) {
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
