// ============================
// File: functions/src/usageLimits.ts
// ============================
import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const db = admin.firestore();

// Rolling 30-day window in ms
const MONTH_MS = 30 * 24 * 60 * 60 * 1000;

export type UsageField = "manualSendsThisMonth" | "pdfExportsThisMonth";

/**
 * Enforces a per-user monthly (30-day) limit on a given usage field.
 * If under the limit, increments the counter in a transaction.
 * If at/over the limit, throws a resource-exhausted HttpsError with your message.
 */
export async function enforceMonthlyLimit(
  uid: string,
  field: UsageField,
  limit: number
): Promise<void> {
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const data = snap.data() || {};
    const usage = (data.usage as any) || {};

    const now = Date.now();
    let windowStart =
      typeof usage.usagePeriodStart === "number" ? usage.usagePeriodStart : now;
    let count = typeof usage[field] === "number" ? usage[field] : 0;

    logger.info("[usageLimits] before", {
      uid,
      field,
      limit,
      windowStart,
      count,
      rawUsage: usage,
    });

    // Reset window if older than 30 days
    if (now - windowStart > MONTH_MS) {
      windowStart = now;
      count = 0;
    }

    if (count >= limit) {
      logger.warn("[usageLimits] limit hit", { uid, field, limit, count });
      throw new HttpsError(
        "resource-exhausted",
        "We're so sorry - but you've hit the maximum number of on-demand monthly ReMinders that our backend can support per user. You will still get the regular random ReMinders until this resets!"
      );
    }

    const newUsage = {
      ...usage,
      usagePeriodStart: windowStart,
      [field]: count + 1,
    };

    logger.info("[usageLimits] writing usage", { uid, field, newUsage });

    tx.set(userRef, { usage: newUsage }, { merge: true });
  });
}
