// ============================
// File: functions/src/scheduler/reconcileRevenueCatEntitlements.ts
// ============================
import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db, logger } from "../config/options";
import { parseRcExpiresAt } from "../revenuecat/state";

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

    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    let batchNumber = 0;
    let expiredCount = 0;
    let checked = 0;

    while (true) {
      let query = db.collection("users").where("rc.entitlementActive", "==", true).orderBy(admin.firestore.FieldPath.documentId());
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const activeSnap = await query.limit(BATCH_LIMIT).get();

      if (activeSnap.empty) {
        break;
      }

      batchNumber += 1;
      checked += activeSnap.size;

      logger.info("[reconcileRevenueCatEntitlements] processing batch", {
        batchNumber,
        batchSize: activeSnap.size,
        checked,
        expiredCount,
      });

      for (const doc of activeSnap.docs) {
        const expiresRaw = doc.get("rc.expiresAt");
        const { expiresAt, expiresAtSeconds, needsNormalization } = parseRcExpiresAt(expiresRaw);

        if (needsNormalization && expiresAt) {
          await doc.ref.set({ rc: { expiresAt } }, { merge: true });
          logger.info("[reconcileRevenueCatEntitlements] normalized rc.expiresAt", {
            uid: doc.id,
            expiresAtSeconds,
          });
        }

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

      lastDoc = activeSnap.docs[activeSnap.docs.length - 1];
    }

    logger.info("[reconcileRevenueCatEntitlements] complete", {
      checked,
      expiredCount,
      batches: batchNumber,
    });
  }
);
