// ============================
// File: functions/src/revenuecat/webhook.ts
// ============================
import { onRequest } from "firebase-functions/v2/https";
import { admin, db, logger, REVENUECAT_WEBHOOK_AUTH } from "../config/options";
import { deriveSubscriptionState, parseRcExpiresAt } from "./state";
import { isValidRevenueCatWebhook } from "../security/webhooks";

type RevenueCatEvent = Record<string, unknown>;

type WebhookPayload = {
  event?: RevenueCatEvent;
} & RevenueCatEvent;

const USER_ID_FIELDS = [
  "app_user_id",
  "appUserId",
  "original_app_user_id",
  "originalAppUserId",
  "subscriber_id",
  "subscriberId",
  "customer_id",
  "customerId",
] as const;

export type RevenueCatWebhookResult =
  | {
      ok: true;
      status: 200;
      kind: "subscription";
      event: RevenueCatEvent;
      eventType: string;
      appUserId: string;
      update: Record<string, unknown>;
      logContext: Record<string, unknown>;
    }
  | {
      ok: true;
      status: 200;
      kind: "transfer";
      event: RevenueCatEvent;
      eventType: "TRANSFER";
      transferredTo: string[];
      transferredFrom: string[];
      logContext: Record<string, unknown>;
    }
  | {
      ok: false;
      status: 400;
      error: string;
      event: RevenueCatEvent;
      eventType: string;
      appUserId: string | null;
      logContext: Record<string, unknown>;
    };

function parseSecondsFromMillis(raw: unknown): number | null {
  if (raw == null) return null;
  const asNumber = typeof raw === "string" ? Number(raw) : (raw as number);
  if (!Number.isFinite(asNumber)) return null;
  return asNumber / 1000;
}

export function normalizeEvent(body: WebhookPayload): RevenueCatEvent {
  if (body?.event && typeof body.event === "object") {
    return body.event as RevenueCatEvent;
  }
  return body as RevenueCatEvent;
}

function safeKeys(value: unknown): string[] {
  if (!value || typeof value !== "object" || Array.isArray(value)) return [];
  return Object.keys(value as Record<string, unknown>).sort();
}

function stringField(source: RevenueCatEvent, field: string): string | null {
  const value = source[field];
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function firstAlias(source: RevenueCatEvent): string | null {
  const aliases = source.aliases;
  if (!Array.isArray(aliases)) return null;

  for (const alias of aliases) {
    if (typeof alias === "string" && alias.trim()) {
      return alias.trim();
    }
  }
  return null;
}

function stringAliases(source: RevenueCatEvent): string[] {
  const aliases = source.aliases;
  if (!Array.isArray(aliases)) return [];
  return aliases
    .filter((alias): alias is string => typeof alias === "string" && !!alias.trim())
    .map((alias) => alias.trim());
}

function revenueCatIdentifierFields(event: RevenueCatEvent, body: WebhookPayload) {
  return Object.fromEntries(
    USER_ID_FIELDS.flatMap((field) => {
      const value = stringField(event, field) ?? stringField(body, field);
      return value ? [[field, value]] : [];
    })
  );
}

function stringArrayField(source: RevenueCatEvent, field: string): string[] {
  const value = source[field];
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === "string" && !!item.trim())
    .map((item) => item.trim());
}

function transferIds(event: RevenueCatEvent) {
  return {
    transferredTo: stringArrayField(event, "transferred_to"),
    transferredFrom: stringArrayField(event, "transferred_from"),
  };
}

export function revenueCatWebhookLogContext(body: WebhookPayload, event: RevenueCatEvent) {
  const { transferredTo, transferredFrom } = transferIds(event);
  const appUserId = extractRevenueCatAppUserId(event, body);

  return {
    eventType: String(event?.type ?? "").toUpperCase(),
    appUserId,
    appUserIdExists: appUserId != null,
    transferredToExists: transferredTo.length > 0,
    transferredFromExists: transferredFrom.length > 0,
    transferredToCount: transferredTo.length,
    transferredFromCount: transferredFrom.length,
    aliases: [...stringAliases(event), ...stringAliases(body)].slice(0, 5),
    identifierFields: revenueCatIdentifierFields(event, body),
    payloadKeys: safeKeys(body),
    eventKeys: safeKeys(event),
  };
}

export function extractRevenueCatAppUserId(
  event: RevenueCatEvent,
  body: WebhookPayload = {} as WebhookPayload
): string | null {
  for (const field of USER_ID_FIELDS) {
    const value = stringField(event, field) ?? stringField(body, field);
    if (value) return value;
  }

  return firstAlias(event) ?? firstAlias(body);
}

export function buildRevenueCatWebhookResult(
  body: WebhookPayload,
  nowSeconds = Date.now() / 1000
): RevenueCatWebhookResult {
  const event = normalizeEvent(body);
  const eventType = String(event?.type ?? "").toUpperCase();
  const appUserId = extractRevenueCatAppUserId(event, body);
  const logContext = revenueCatWebhookLogContext(body, event);

  if (!eventType) {
    return {
      ok: false,
      status: 400,
      error: "Missing event type",
      event,
      eventType,
      appUserId,
      logContext,
    };
  }

  if (eventType === "TRANSFER") {
    const { transferredTo, transferredFrom } = transferIds(event);
    if (transferredTo.length === 0 && transferredFrom.length === 0) {
      return {
        ok: false,
        status: 400,
        error: "Missing RevenueCat transfer identifiers",
        event,
        eventType,
        appUserId,
        logContext,
      };
    }

    return {
      ok: true,
      status: 200,
      kind: "transfer",
      event,
      eventType: "TRANSFER",
      transferredTo,
      transferredFrom,
      logContext,
    };
  }

  if (!appUserId) {
    return {
      ok: false,
      status: 400,
      error: "Missing RevenueCat app user id",
      event,
      eventType,
      appUserId,
      logContext,
    };
  }

  const expiresAtSeconds =
    parseSecondsFromMillis(event?.expiration_at_ms) ??
    parseSecondsFromMillis((event as Record<string, unknown>)["expires_at_ms"]) ??
    parseSecondsFromMillis((event as Record<string, unknown>)["expiration_ms"]);

  const { expiresAt } = parseRcExpiresAt(expiresAtSeconds);

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

  const paidPeriodFromExpiry = expiresAtSeconds != null && expiresAtSeconds >= nowSeconds;
  const inferredEntitlementActive =
    entitlementActiveFromEvent ??
    (expiresAtSeconds != null ? paidPeriodFromExpiry : eventType !== "EXPIRATION");
  const entitlementActive =
    eventType !== "EXPIRATION" &&
    (paidPeriodFromExpiry || inferredEntitlementActive);

  const derived = deriveSubscriptionState(
    {
      entitlementActive,
      willRenew: willRenewFromEvent,
      expiresAt,
    },
    nowSeconds
  );

  const rcUpdate: Record<string, unknown> = {
    entitlementActive: derived.entitlementActive,
    willRenew: derived.willRenew,
    productId: event?.product_id ?? event?.productId ?? null,
    expiresAt,
    latestPurchaseAt: purchasedAtSeconds,
    store: event?.store ?? (event?.platform as string | undefined) ?? "app_store",
    lastWebhookEventAt: admin.firestore.FieldValue.serverTimestamp(),
    lastWebhookEventType: eventType,
  };

  const update: Record<string, unknown> = {
    rc: rcUpdate,
    plan: derived.plan,
    subscriptionStatus: derived.subscriptionStatus,
  };

  return {
    ok: true,
    status: 200,
    kind: "subscription",
    event,
    eventType,
    appUserId,
    update,
    logContext: {
      ...logContext,
      entitlementActive: derived.entitlementActive,
      willRenew: derived.willRenew,
      expiresAtSeconds,
      plan: derived.plan,
      subscriptionStatus: derived.subscriptionStatus,
    },
  };
}

function firestoreSafeUid(uid: string): boolean {
  return uid.length > 0 && !uid.includes("/");
}

function uniqueSafeUids(uids: string[]): string[] {
  return [...new Set(uids.filter(firestoreSafeUid))];
}

function timestampSeconds(raw: unknown): number | null {
  if (raw == null) return null;
  if (raw instanceof admin.firestore.Timestamp) {
    return raw.seconds + raw.nanoseconds / 1_000_000_000;
  }
  if (typeof raw === "object" && "seconds" in raw) {
    const seconds = Number((raw as { seconds?: unknown }).seconds);
    return Number.isFinite(seconds) ? seconds : null;
  }
  const numeric = typeof raw === "string" ? Number(raw) : (raw as number);
  if (Number.isFinite(numeric)) return numeric > 10_000_000_000 ? numeric / 1000 : numeric;
  return null;
}

function sourceLooksPaid(source: Record<string, unknown>, nowSeconds: number): boolean {
  const rc = (source.rc ?? {}) as Record<string, unknown>;
  const expiresAtSeconds = timestampSeconds(rc.expiresAt);
  const expiresInFuture = expiresAtSeconds == null || expiresAtSeconds >= nowSeconds;
  const activeMirror = rc.entitlementActive === true && expiresInFuture;
  const plan = String(source.plan ?? "").toLowerCase();
  const status = String(source.subscriptionStatus ?? "").toLowerCase();

  return (
    activeMirror ||
    (plan === "pro" && expiresInFuture) ||
    ((status === "subscribed" || status === "cancelled" || status === "active") &&
      expiresInFuture)
  );
}

export function buildRevenueCatTransferFromUpdate(eventType = "TRANSFER") {
  return {
    rc: {
      entitlementActive: false,
      willRenew: false,
      lastWebhookEventAt: admin.firestore.FieldValue.serverTimestamp(),
      lastWebhookEventType: eventType,
      lastTransferDirection: "from",
    },
    plan: "free",
    subscriptionStatus: "unsubscribed",
  };
}

export function buildRevenueCatTransferToUpdate(
  source: Record<string, unknown> | null,
  transferredFrom: string[],
  eventType = "TRANSFER",
  nowSeconds = Date.now() / 1000
) {
  const sourceRc =
    source && typeof source.rc === "object" && source.rc != null
      ? (source.rc as Record<string, unknown>)
      : {};
  const hasPaidSource = source != null && sourceLooksPaid(source, nowSeconds);
  const baseRc = hasPaidSource ? sourceRc : {};

  return {
    rc: {
      ...baseRc,
      entitlementActive: hasPaidSource ? true : baseRc.entitlementActive ?? false,
      lastWebhookEventAt: admin.firestore.FieldValue.serverTimestamp(),
      lastWebhookEventType: eventType,
      lastTransferDirection: "to",
      transferredFrom: transferredFrom.slice(0, 10),
      transferPending: !hasPaidSource,
    },
    ...(hasPaidSource
      ? {
          plan: "pro",
          subscriptionStatus: String(source?.subscriptionStatus ?? "subscribed"),
        }
      : {}),
  };
}

async function handleTransferEvent(
  result: Extract<RevenueCatWebhookResult, { kind: "transfer" }>
) {
  const transferredTo = uniqueSafeUids(result.transferredTo);
  const transferredFrom = uniqueSafeUids(result.transferredFrom);
  const skippedTo = result.transferredTo.length - transferredTo.length;
  const skippedFrom = result.transferredFrom.length - transferredFrom.length;
  const nowSeconds = Date.now() / 1000;

  const sourceSnaps = await Promise.all(
    transferredFrom.map((uid) => db.doc(`users/${uid}`).get())
  );
  const sourceData =
    sourceSnaps.find((snap) => snap.exists && sourceLooksPaid(snap.data() ?? {}, nowSeconds))
      ?.data() ?? null;

  const batch = db.batch();
  for (const uid of transferredFrom) {
    batch.set(db.doc(`users/${uid}`), buildRevenueCatTransferFromUpdate(result.eventType), {
      merge: true,
    });
  }
  for (const uid of transferredTo) {
    batch.set(
      db.doc(`users/${uid}`),
      buildRevenueCatTransferToUpdate(sourceData, transferredFrom, result.eventType, nowSeconds),
      { merge: true }
    );
  }

  await batch.commit();

  return {
    transferredTo,
    transferredFrom,
    skippedTo,
    skippedFrom,
    copiedPaidSource: sourceData != null,
  };
}

export const revenueCatWebhook = onRequest(
  { secrets: [REVENUECAT_WEBHOOK_AUTH] },
  async (req, res) => {
    if (req.method !== "POST") {
      logger.warn("[revenueCatWebhook] rejected request", {
        reason: "invalid_method",
        method: req.method,
        responseStatus: 405,
      });
      res.status(405).send("Method Not Allowed");
      return;
    }

    if (!isValidRevenueCatWebhook(req.headers, REVENUECAT_WEBHOOK_AUTH.value())) {
      const body = (req.body ?? {}) as WebhookPayload;
      const event = normalizeEvent(body);
      logger.warn("[revenueCatWebhook] rejected request", {
        reason: "invalid_authorization",
        responseStatus: 401,
        ...revenueCatWebhookLogContext(body, event),
      });
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const result = buildRevenueCatWebhookResult(req.body as WebhookPayload);
    if (!result.ok) {
      logger.warn("[revenueCatWebhook] rejected request", {
        reason: result.error,
        responseStatus: result.status,
        ...result.logContext,
      });
      res.status(result.status).json({ error: result.error });
      return;
    }

    if (result.kind === "transfer") {
      const transferWrite = await handleTransferEvent(result);
      logger.info("[revenueCatWebhook] processed", {
        responseStatus: 200,
        ...result.logContext,
        ...transferWrite,
      });
      res.status(200).json({ received: true });
      return;
    }

    const userRef = db.doc(`users/${result.appUserId}`);
    const userSnap = await userRef.get();
    const optedOut = userSnap.get("smsOptOut") === true;
    const update = { ...result.update };

    if (optedOut) {
      update.active = false;
    }

    await userRef.set(update, { merge: true });

    logger.info("[revenueCatWebhook] processed", {
      uid: result.appUserId,
      responseStatus: 200,
      ...result.logContext,
    });

    res.status(200).json({ received: true });
  }
);
