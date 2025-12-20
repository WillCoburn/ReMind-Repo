// ============================
// File: functions/src/scheduler/reconcileRevenueCatEntitlements.ts
// ============================
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db, logger } from "../config/options";
import { secondsFromTimestamp } from "../revenuecat/state";

const BATCH_LIMIT = 500;

export const reconcileRevenueCatEntitlements = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "UTC",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const nowSeconds = now.seconds + now.nanoseconds / 1_000_000_000;

    logger.info("[reconcileRevenueCatEntitlements] start", { now: now.toDate().toISOString() });

    const activeSnap = await db
      .collection("users")
      .where("rc.entitlementActive", "==", true)
      .limit(BATCH_LIMIT)
      .get();

    if (activeSnap.empty) {
      logger.info("[reconcileRevenueCatEntitlements] no active entitlements found");
      return;
    }

    let expiredCount = 0;

    for (const doc of activeSnap.docs) {
      const expiresRaw = doc.get("rc.expiresAt");
      const expiresAtSeconds = secondsFromTimestamp(expiresRaw);

      if (expiresAtSeconds == null) {
        continue;
      }

      if (expiresAtSeconds > nowSeconds) {
        continue;
      }

      expiredCount += 1;

      await doc.ref.set(
        {
          rc: {
            entitlementActive: false,
            willRenew: false,
          },
          active: false,
          subscriptionStatus: "unsubscribed",
        },
        { merge: true }
      );

      logger.warn("[reconcileRevenueCatEntitlements] deactivated expired user", {
        uid: doc.id,
        expiresAtSeconds,
      });
    }

    logger.info("[reconcileRevenueCatEntitlements] complete", {
      checked: activeSnap.size,
      expiredCount,
    });
  }
);
