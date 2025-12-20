// ============================
// File: functions/src/revenuecat/state.ts
// ============================
import { admin } from "../config/options";

export function parseRcExpiresAt(raw: unknown): {
  expiresAt: admin.firestore.Timestamp | null;
  expiresAtSeconds: number | null;
  needsNormalization: boolean;
} {
  if (raw == null) {
    return { expiresAt: null, expiresAtSeconds: null, needsNormalization: false };
  }

  if (raw instanceof admin.firestore.Timestamp) {
    const expiresAtSeconds = raw.seconds + raw.nanoseconds / 1_000_000_000;
    return { expiresAt: raw, expiresAtSeconds, needsNormalization: false };
  }

  const asNumber = typeof raw === "string" ? Number(raw) : (raw as number);
  if (!Number.isFinite(asNumber)) {
    return { expiresAt: null, expiresAtSeconds: null, needsNormalization: false };
  }

  const expiresAtSeconds = asNumber;
  const expiresAt = admin.firestore.Timestamp.fromMillis(expiresAtSeconds * 1000);

  return { expiresAt, expiresAtSeconds, needsNormalization: true };
}

export function deriveSubscriptionState(
  rc: Partial<{
    entitlementActive: boolean;
    willRenew: boolean;
    expiresAt: unknown;
  }>,
  nowSeconds = Date.now() / 1000
) {
  const { expiresAtSeconds } = parseRcExpiresAt(rc.expiresAt);

  const entitlementActive =
    typeof rc.entitlementActive === "boolean"
      ? rc.entitlementActive
      : expiresAtSeconds != null
      ? expiresAtSeconds >= nowSeconds
      : false;

  const willRenew = rc.willRenew ?? false;

  const inPaidPeriod = entitlementActive && (expiresAtSeconds ?? nowSeconds) >= nowSeconds;

  const subscriptionStatus = inPaidPeriod
    ? willRenew
      ? "subscribed"
      : "cancelled"
    : "unsubscribed";

  return { entitlementActive, willRenew, expiresAtSeconds, inPaidPeriod, subscriptionStatus };
}
