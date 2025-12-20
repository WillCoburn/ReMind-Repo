// ============================
// File: functions/src/revenuecat/state.ts
// ============================
import { admin } from "../config/options";

export function secondsFromTimestamp(raw: unknown): number | null {
  if (raw instanceof admin.firestore.Timestamp) {
    return raw.seconds + raw.nanoseconds / 1_000_000_000;
  }

  if (typeof raw === "number") {
    return Number.isFinite(raw) ? raw : null;
  }

  if (typeof raw === "string") {
    const parsed = Number(raw);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

export function deriveSubscriptionState(
  rc: Partial<{
    entitlementActive: boolean;
    willRenew: boolean;
    expiresAt: number | admin.firestore.Timestamp | null;
  }>,
  nowSeconds = Date.now() / 1000
) {
  const expiresAtSeconds = secondsFromTimestamp(rc.expiresAt);

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
