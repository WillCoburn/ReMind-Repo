import type { RevenueCatEntitlementSnapshot } from "../entitlements/capabilities";

export const REVENUECAT_PRO_ENTITLEMENT_ID = "pro";

type FetchLike = typeof fetch;

type RevenueCatSubscriberResponse = {
  subscriber?: {
    entitlements?: Record<string, Record<string, unknown>>;
  };
};

function parseDateSeconds(raw: unknown): number | null {
  if (raw == null) return null;
  if (typeof raw === "number") return Number.isFinite(raw) ? raw : null;
  if (typeof raw !== "string") return null;

  const numeric = Number(raw);
  if (Number.isFinite(numeric)) return numeric;

  const millis = Date.parse(raw);
  return Number.isFinite(millis) ? millis / 1000 : null;
}

export function parseRevenueCatSubscriberEntitlement(
  response: RevenueCatSubscriberResponse,
  entitlementId = REVENUECAT_PRO_ENTITLEMENT_ID,
  nowSeconds = Date.now() / 1000
): RevenueCatEntitlementSnapshot {
  const entitlement = response.subscriber?.entitlements?.[entitlementId] ?? {};
  const expiresAtSeconds = parseDateSeconds(
    entitlement.expires_date ?? entitlement.expiresDate
  );
  const purchaseDateSeconds = parseDateSeconds(
    entitlement.purchase_date ?? entitlement.purchaseDate
  );
  const productId =
    typeof entitlement.product_identifier === "string"
      ? entitlement.product_identifier
      : typeof entitlement.productId === "string"
      ? entitlement.productId
      : null;

  const entitlementActive =
    Object.keys(entitlement).length > 0 &&
    (expiresAtSeconds == null || expiresAtSeconds >= nowSeconds);

  return {
    entitlementActive,
    expiresAtSeconds,
    productId,
    reason: [
      `entitlementId=${entitlementId}`,
      `purchaseDate=${purchaseDateSeconds ?? "missing"}`,
    ].join(" "),
  };
}

export async function fetchRevenueCatSubscriberEntitlement(
  appUserID: string,
  apiKey: string,
  entitlementId = REVENUECAT_PRO_ENTITLEMENT_ID,
  fetchImpl: FetchLike = fetch
): Promise<RevenueCatEntitlementSnapshot> {
  const url = `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserID)}`;
  const response = await fetchImpl(url, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(
      `RevenueCat subscriber lookup failed (${response.status}) ${body.slice(0, 180)}`
    );
  }

  return parseRevenueCatSubscriberEntitlement(
    (await response.json()) as RevenueCatSubscriberResponse,
    entitlementId
  );
}
