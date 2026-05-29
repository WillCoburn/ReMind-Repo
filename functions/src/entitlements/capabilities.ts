import * as admin from "firebase-admin";

export type ServerPlan = "free" | "pro";
export type ServerCapabilityState = "free" | "pro" | "expired";
export type ServerCapabilitySource =
  | "revenueCatMirror"
  | "revenueCatApi"
  | "serverProfile"
  | "expired"
  | "free";

type SnapshotLike = {
  get(fieldPath: string): unknown;
};

export type ServerCapabilities = {
  state: ServerCapabilityState;
  plan: ServerPlan;
  source: ServerCapabilitySource;
  reason: string;
  canUseProReminderRange: boolean;
  maxRemindersPerWeek: number;
  appliesFreeUsageLimits: boolean;
};

export const SERVER_LIMITS = {
  freeMaxRemindersPerWeek: 3,
  proMaxRemindersPerWeek: 14,
} as const;

export type RevenueCatEntitlementSnapshot = {
  entitlementActive: boolean;
  expiresAtSeconds: number | null;
  willRenew?: boolean | null;
  productId?: string | null;
  reason: string;
};

function proCapabilities(source: ServerCapabilitySource, reason: string): ServerCapabilities {
  return {
    state: "pro",
    plan: "pro",
    source,
    reason,
    canUseProReminderRange: true,
    maxRemindersPerWeek: SERVER_LIMITS.proMaxRemindersPerWeek,
    appliesFreeUsageLimits: false,
  };
}

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
  const serverProfileSubscribed =
    explicitPlan === "pro" ||
    subscriptionStatus === "subscribed" ||
    subscriptionStatus === "active" ||
    subscriptionStatus === "cancelled";

  const isPro =
    !rcExpired &&
    (rcEntitlementActive || serverProfileSubscribed);
  const state: ServerCapabilityState = isPro
    ? "pro"
    : rcExpired || subscriptionStatus === "expired"
    ? "expired"
    : "free";
  const source: ServerCapabilitySource = isPro
    ? rcEntitlementActive
      ? "revenueCatMirror"
      : "serverProfile"
    : state === "expired"
    ? "expired"
    : "free";
  const reason = [
    `source=${source}`,
    `plan=${explicitPlan || "missing"}`,
    `status=${subscriptionStatus || "missing"}`,
    `rcActive=${String(rcEntitlementRaw)}`,
    `rcExpiresAt=${rcExpiresAtSeconds ?? "missing"}`,
  ].join(" ");

  if (isPro) {
    return proCapabilities(source, reason);
  }

  return {
    state,
    plan: "free",
    source,
    reason,
    canUseProReminderRange: false,
    maxRemindersPerWeek: SERVER_LIMITS.freeMaxRemindersPerWeek,
    appliesFreeUsageLimits: true,
  };
}

export function resolveServerCapabilitiesWithRevenueCatEntitlement(
  user: SnapshotLike,
  revenueCat: RevenueCatEntitlementSnapshot | null,
  nowSeconds = Date.now() / 1000
): ServerCapabilities {
  const base = resolveServerCapabilities(user, nowSeconds);
  if (base.plan === "pro") return base;
  if (!revenueCat?.entitlementActive) return base;
  if (revenueCat.expiresAtSeconds != null && revenueCat.expiresAtSeconds < nowSeconds) {
    return base;
  }

  return proCapabilities(
    "revenueCatApi",
    [
      "source=revenueCatApi",
      `rcApiActive=${String(revenueCat.entitlementActive)}`,
      `rcApiExpiresAt=${revenueCat.expiresAtSeconds ?? "missing"}`,
      `rcApiProductId=${revenueCat.productId ?? "missing"}`,
      revenueCat.reason,
    ].join(" ")
  );
}

export function resolveServerPlan(
  user: SnapshotLike,
  nowSeconds = Date.now() / 1000
): ServerPlan {
  return resolveServerCapabilities(user, nowSeconds).plan;
}
