import * as admin from "firebase-admin";

export type ServerPlan = "free" | "pro";
export type ServerCapabilityState = "free" | "pro" | "expired";

type SnapshotLike = {
  get(fieldPath: string): unknown;
};

export type ServerCapabilities = {
  state: ServerCapabilityState;
  plan: ServerPlan;
  canUseProReminderRange: boolean;
  maxRemindersPerWeek: number;
  appliesFreeUsageLimits: boolean;
};

export const SERVER_LIMITS = {
  freeMaxRemindersPerWeek: 3,
  proMaxRemindersPerWeek: 20,
} as const;

export function timestampSeconds(raw: unknown): number | null {
  if (raw == null) return null;
  if (raw instanceof admin.firestore.Timestamp) {
    return raw.seconds + raw.nanoseconds / 1_000_000_000;
  }
  if (raw instanceof Date) {
    return raw.getTime() / 1000;
  }
  const asNumber = typeof raw === "string" ? Number(raw) : (raw as number);
  return Number.isFinite(asNumber) ? asNumber : null;
}

export function resolveServerCapabilities(
  user: SnapshotLike,
  nowSeconds = Date.now() / 1000
): ServerCapabilities {
  const explicitPlan = String(user.get("plan") ?? "").toLowerCase();
  const subscriptionStatus = String(user.get("subscriptionStatus") ?? "").toLowerCase();
  const rcEntitlementRaw = user.get("rc.entitlementActive");
  const rcEntitlementActive = rcEntitlementRaw === true;
  const rcExpiresAtSeconds = timestampSeconds(user.get("rc.expiresAt"));
  const rcExpired = rcExpiresAtSeconds != null && rcExpiresAtSeconds < nowSeconds;
  const hasRevenueCatMirror = rcEntitlementRaw != null || rcExpiresAtSeconds != null;

  const isPro =
    (rcEntitlementActive && !rcExpired) ||
    (!hasRevenueCatMirror && explicitPlan === "pro");
  const state: ServerCapabilityState = isPro
    ? "pro"
    : rcExpired || subscriptionStatus === "expired"
    ? "expired"
    : "free";

  return {
    state,
    plan: isPro ? "pro" : "free",
    canUseProReminderRange: isPro,
    maxRemindersPerWeek: isPro
      ? SERVER_LIMITS.proMaxRemindersPerWeek
      : SERVER_LIMITS.freeMaxRemindersPerWeek,
    appliesFreeUsageLimits: !isPro,
  };
}

export function resolveServerPlan(
  user: SnapshotLike,
  nowSeconds = Date.now() / 1000
): ServerPlan {
  return resolveServerCapabilities(user, nowSeconds).plan;
}
