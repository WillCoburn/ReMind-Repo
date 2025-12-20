// ============================
// File: functions/src/revenuecat/webhook.ts
// ============================
import { onRequest } from "firebase-functions/v2/https";
import { admin, db, logger } from "../config/options";
import { deriveSubscriptionState } from "./state";

type RevenueCatEvent = Record<string, unknown>;

type WebhookPayload = {
  event?: RevenueCatEvent;
} & RevenueCatEvent;

function parseSecondsFromMillis(raw: unknown): number | null {
  if (raw == null) return null;
  const asNumber = typeof raw === "string" ? Number(raw) : (raw as number);
  if (!Number.isFinite(asNumber)) return null;
  return asNumber / 1000;
}

function normalizeEvent(body: WebhookPayload): RevenueCatEvent {
  if (body?.event && typeof body.event === "object") {
    return body.event as RevenueCatEvent;
  }
  return body as RevenueCatEvent;
}

export const revenueCatWebhook = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const event = normalizeEvent(req.body as WebhookPayload);
  const eventType = String(event?.type ?? "").toUpperCase();
  const appUserId = (event?.app_user_id ?? event?.appUserId ?? "").toString();

  if (!appUserId) {
    res.status(400).json({ error: "Missing app_user_id" });
    return;
  }

  const nowSeconds = Date.now() / 1000;
  const expiresAtSeconds =
    parseSecondsFromMillis(event?.expiration_at_ms) ??
    parseSecondsFromMillis((event as Record<string, unknown>)["expires_at_ms"]) ??
    parseSecondsFromMillis((event as Record<string, unknown>)["expiration_ms"]);

  const purchasedAtSeconds =
    parseSecondsFromMillis(event?.purchased_at_ms) ??
    parseSecondsFromMillis((event as Record<string, unknown>)["original_purchase_date_ms"]);

  const entitlementStatus = (event?.entitlement_status ?? event?.entitlementStatus ?? "")
    .toString()
    .toLowerCase();
  const entitlementActiveFromEvent =
    typeof event?.entitlement_active === "boolean"
      ? (event.entitlement_active as boolean)
      : entitlementStatus === "active"
      ? true
      : entitlementStatus === "expired"
      ? false
      : undefined;

  const willRenewFromEvent =
    typeof event?.will_renew === "boolean"
      ? (event.will_renew as boolean)
      : eventType === "CANCELLATION" || eventType === "EXPIRATION"
      ? false
      : true;

  const derived = deriveSubscriptionState(
    {
      entitlementActive:
        entitlementActiveFromEvent ?? (expiresAtSeconds != null ? expiresAtSeconds >= nowSeconds : eventType !== "EXPIRATION"),
      willRenew: willRenewFromEvent,
      expiresAt: expiresAtSeconds,
    },
    nowSeconds
  );

  const rcUpdate: Record<string, unknown> = {
    entitlementActive: derived.entitlementActive,
    willRenew: derived.willRenew,
    productId: event?.product_id ?? event?.productId ?? null,
    expiresAt: expiresAtSeconds,
    latestPurchaseAt: purchasedAtSeconds,
    store: event?.store ?? (event?.platform as string | undefined) ?? "app_store",
    lastWebhookEventAt: admin.firestore.FieldValue.serverTimestamp(),
    lastWebhookEventType: eventType,
  };

  await db
    .doc(`users/${appUserId}`)
    .set(
      {
        rc: rcUpdate,
        active: derived.inPaidPeriod,
        subscriptionStatus: derived.subscriptionStatus,
      },
      { merge: true }
    );

  logger.info("[revenueCatWebhook] processed", {
    uid: appUserId,
    type: eventType,
    entitlementActive: derived.entitlementActive,
    willRenew: derived.willRenew,
    expiresAtSeconds,
  });

  res.status(200).json({ received: true });
});
