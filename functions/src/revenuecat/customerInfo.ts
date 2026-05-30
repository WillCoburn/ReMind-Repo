import type { RevenueCatEntitlementSnapshot } from "../entitlements/capabilities";

export const REVENUECAT_PRO_ENTITLEMENT_LOOKUP_KEY = "pro";

type FetchLike = typeof fetch;

type RevenueCatV2List<T> = {
  items?: T[];
  next_page?: string | null;
};

type RevenueCatV2Entitlement = {
  id?: unknown;
  lookup_key?: unknown;
  display_name?: unknown;
};

type RevenueCatV2ActiveEntitlement = {
  entitlement_id?: unknown;
  expires_at?: unknown;
};

function parseDateSeconds(raw: unknown): number | null {
  if (raw == null) return null;
  if (typeof raw === "number") {
    if (!Number.isFinite(raw)) return null;
    return raw > 10_000_000_000 ? raw / 1000 : raw;
  }
  if (typeof raw !== "string") return null;

  const numeric = Number(raw);
  if (Number.isFinite(numeric)) {
    return numeric > 10_000_000_000 ? numeric / 1000 : numeric;
  }

  const millis = Date.parse(raw);
  return Number.isFinite(millis) ? millis / 1000 : null;
}

function revenueCatV2Url(path: string): string {
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return `https://api.revenuecat.com/v2${normalizedPath}`;
}

async function fetchRevenueCatV2Json<T>(
  path: string,
  secretApiKey: string,
  fetchImpl: FetchLike
): Promise<T> {
  const response = await fetchImpl(revenueCatV2Url(path), {
    method: "GET",
    headers: {
      Authorization: `Bearer ${secretApiKey}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(
      `RevenueCat v2 lookup failed (${response.status}) ${body.slice(0, 180)}`
    );
  }

  return (await response.json()) as T;
}

export function parseRevenueCatV2ActiveEntitlement(
  entitlements: RevenueCatV2List<RevenueCatV2Entitlement>,
  activeEntitlements: RevenueCatV2List<RevenueCatV2ActiveEntitlement>,
  entitlementLookupKey = REVENUECAT_PRO_ENTITLEMENT_LOOKUP_KEY,
  nowSeconds = Date.now() / 1000
): RevenueCatEntitlementSnapshot {
  const entitlement = entitlements.items?.find(
    (item) => item.lookup_key === entitlementLookupKey
  );
  const entitlementId = typeof entitlement?.id === "string" ? entitlement.id : null;
  const activeEntitlement = entitlementId
    ? activeEntitlements.items?.find((item) => item.entitlement_id === entitlementId)
    : undefined;
  const expiresAtSeconds = parseDateSeconds(activeEntitlement?.expires_at);
  const entitlementActive =
    activeEntitlement != null &&
    (expiresAtSeconds == null || expiresAtSeconds >= nowSeconds);

  return {
    entitlementActive,
    expiresAtSeconds,
    productId: null,
    reason: [
      "api=v2",
      `entitlementLookupKey=${entitlementLookupKey}`,
      `entitlementId=${entitlementId ?? "missing"}`,
    ].join(" "),
  };
}

export async function fetchRevenueCatSubscriberEntitlement(
  appUserID: string,
  secretApiKey: string,
  projectId: string,
  entitlementLookupKey = REVENUECAT_PRO_ENTITLEMENT_LOOKUP_KEY,
  fetchImpl: FetchLike = fetch
): Promise<RevenueCatEntitlementSnapshot> {
  const encodedProjectId = encodeURIComponent(projectId);
  const encodedAppUserID = encodeURIComponent(appUserID);

  const [entitlements, activeEntitlements] = await Promise.all([
    fetchRevenueCatV2Json<RevenueCatV2List<RevenueCatV2Entitlement>>(
      `/projects/${encodedProjectId}/entitlements?limit=100`,
      secretApiKey,
      fetchImpl
    ),
    fetchRevenueCatV2Json<RevenueCatV2List<RevenueCatV2ActiveEntitlement>>(
      `/projects/${encodedProjectId}/customers/${encodedAppUserID}/active_entitlements?limit=100`,
      secretApiKey,
      fetchImpl
    ),
  ]);

  return parseRevenueCatV2ActiveEntitlement(
    entitlements,
    activeEntitlements,
    entitlementLookupKey
  );
}
