import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";
import twilio from "twilio";

const require = createRequire(import.meta.url);

const {
  isValidRevenueCatWebhook,
  isValidTwilioWebhookRequest,
  twilioWebhookUrl,
} = require("../lib/security/webhooks.js");
const {
  assertSmsDeliveryAllowed,
  smsDeliveryBlockReason,
} = require("../lib/sms/eligibility.js");
const { canTargetUid } = require("../lib/auth/callable.js");
const {
  buildRevenueCatWebhookResult,
  buildRevenueCatTransferFromUpdate,
  buildRevenueCatTransferToUpdate,
  extractRevenueCatAppUserId,
  normalizeEvent,
} = require("../lib/revenuecat/webhook.js");

test("RevenueCat webhook validation rejects missing or wrong authorization", () => {
  assert.equal(isValidRevenueCatWebhook({}, "shared-secret"), false);
  assert.equal(isValidRevenueCatWebhook({ authorization: "Bearer shared-secret" }, ""), false);
  assert.equal(
    isValidRevenueCatWebhook({ authorization: "Bearer wrong" }, "shared-secret"),
    false
  );
  assert.equal(
    isValidRevenueCatWebhook({ authorization: "wrong" }, "shared-secret"),
    false
  );
});

test("RevenueCat webhook validation accepts the configured shared secret", () => {
  assert.equal(
    isValidRevenueCatWebhook({ authorization: "shared-secret" }, "shared-secret"),
    true
  );
  assert.equal(
    isValidRevenueCatWebhook({ authorization: "Bearer shared-secret" }, "shared-secret"),
    true
  );
  assert.equal(
    isValidRevenueCatWebhook({ Authorization: "bearer shared-secret" }, "shared-secret"),
    true
  );
});

test("RevenueCat webhook parser accepts initial purchase and writes active Pro state", () => {
  const result = buildRevenueCatWebhookResult(
    {
      event: {
        type: "INITIAL_PURCHASE",
        app_user_id: "user-initial",
        product_id: "remind.monthly.099.us",
        purchased_at_ms: 1_780_121_633_000,
        expiration_at_ms: 1_780_122_813_000,
        store: "APP_STORE",
      },
    },
    1_780_121_900
  );

  assert.equal(result.ok, true);
  assert.equal(result.status, 200);
  assert.equal(result.appUserId, "user-initial");
  assert.equal(result.update.plan, "pro");
  assert.equal(result.update.subscriptionStatus, "subscribed");
  assert.equal(result.update.rc.lastWebhookEventType, "INITIAL_PURCHASE");
  assert.equal(result.update.rc.entitlementActive, true);
});

test("RevenueCat webhook parser accepts sandbox renewal and auto-renewal identifier fallbacks", () => {
  const renewal = buildRevenueCatWebhookResult(
    {
      api_version: "1.0",
      event: {
        type: "RENEWAL",
        aliases: ["alias-renewal"],
        product_id: "remind.monthly.099.us",
        expiration_at_ms: 1_780_122_813_000,
        environment: "SANDBOX",
      },
    },
    1_780_121_900
  );

  assert.equal(renewal.ok, true);
  assert.equal(renewal.appUserId, "alias-renewal");
  assert.equal(renewal.update.plan, "pro");
  assert.equal(renewal.update.subscriptionStatus, "subscribed");
  assert.equal(renewal.logContext.eventType, "RENEWAL");
  assert.deepEqual(renewal.logContext.aliases, ["alias-renewal"]);

  const autoRenewal = buildRevenueCatWebhookResult(
    {
      type: "RENEWAL",
      original_app_user_id: "original-renewal-user",
      app_id: "appc16f0086fa",
      expiration_at_ms: 1_780_122_813_000,
      product_id: "remind.monthly.099.us",
    },
    1_780_121_900
  );

  assert.equal(autoRenewal.ok, true);
  assert.equal(autoRenewal.appUserId, "original-renewal-user");
  assert.equal(autoRenewal.update.rc.lastWebhookEventType, "RENEWAL");
});

test("RevenueCat webhook parser accepts transfer events without app_user_id", () => {
  const transfer = buildRevenueCatWebhookResult({
    api_version: "1.0",
    event: {
      app_id: "appc16f0086fa",
      environment: "SANDBOX",
      event_timestamp_ms: 1_780_251_500_000,
      id: "transfer-event-id",
      store: "APP_STORE",
      subscriber_attributes: {},
      transferred_from: ["old-user"],
      transferred_to: ["new-user"],
      type: "TRANSFER",
    },
  });

  assert.equal(transfer.ok, true);
  assert.equal(transfer.kind, "transfer");
  assert.equal(transfer.eventType, "TRANSFER");
  assert.deepEqual(transfer.transferredFrom, ["old-user"]);
  assert.deepEqual(transfer.transferredTo, ["new-user"]);
  assert.equal(transfer.logContext.appUserIdExists, false);
  assert.equal(transfer.logContext.transferredToExists, true);
  assert.equal(transfer.logContext.transferredFromExists, true);
  assert.deepEqual(transfer.logContext.payloadKeys, ["api_version", "event"]);
});

test("RevenueCat webhook parser rejects malformed transfer events with clear context", () => {
  const transfer = buildRevenueCatWebhookResult({
    event: {
      type: "TRANSFER",
      app_id: "appc16f0086fa",
    },
  });

  assert.equal(transfer.ok, false);
  assert.equal(transfer.status, 400);
  assert.equal(transfer.error, "Missing RevenueCat transfer identifiers");
  assert.equal(transfer.logContext.eventType, "TRANSFER");
  assert.equal(transfer.logContext.appUserIdExists, false);
  assert.equal(transfer.logContext.transferredToExists, false);
});

test("RevenueCat transfer updates clear source and mirror active source to destination", () => {
  const fromUpdate = buildRevenueCatTransferFromUpdate();
  assert.equal(fromUpdate.plan, "free");
  assert.equal(fromUpdate.subscriptionStatus, "unsubscribed");
  assert.equal(fromUpdate.rc.entitlementActive, false);
  assert.equal(fromUpdate.rc.lastWebhookEventType, "TRANSFER");
  assert.equal(fromUpdate.rc.lastTransferDirection, "from");

  const toUpdate = buildRevenueCatTransferToUpdate(
    {
      plan: "pro",
      subscriptionStatus: "subscribed",
      rc: {
        entitlementActive: true,
        willRenew: true,
        expiresAt: 2_000,
        productId: "remind.monthly.099.us",
      },
    },
    ["old-user"],
    "TRANSFER",
    1_000
  );

  assert.equal(toUpdate.plan, "pro");
  assert.equal(toUpdate.subscriptionStatus, "subscribed");
  assert.equal(toUpdate.rc.entitlementActive, true);
  assert.equal(toUpdate.rc.willRenew, true);
  assert.equal(toUpdate.rc.lastWebhookEventType, "TRANSFER");
  assert.equal(toUpdate.rc.lastTransferDirection, "to");
  assert.equal(toUpdate.rc.transferPending, false);
  assert.deepEqual(toUpdate.rc.transferredFrom, ["old-user"]);
});

test("RevenueCat transfer destination is marked pending when no paid source mirror exists", () => {
  const toUpdate = buildRevenueCatTransferToUpdate(null, ["old-user"], "TRANSFER", 1_000);

  assert.equal(toUpdate.plan, undefined);
  assert.equal(toUpdate.subscriptionStatus, undefined);
  assert.equal(toUpdate.rc.entitlementActive, false);
  assert.equal(toUpdate.rc.transferPending, true);
  assert.equal(toUpdate.rc.lastTransferDirection, "to");
});

test("RevenueCat webhook parser updates cancelled, expired, and test events", () => {
  const cancellation = buildRevenueCatWebhookResult(
    {
      event: {
        type: "CANCELLATION",
        appUserId: "user-cancelled",
        expiration_at_ms: 1_780_122_813_000,
      },
    },
    1_780_121_900
  );

  assert.equal(cancellation.ok, true);
  assert.equal(cancellation.update.plan, "pro");
  assert.equal(cancellation.update.subscriptionStatus, "cancelled");
  assert.equal(cancellation.update.rc.willRenew, false);

  const expiration = buildRevenueCatWebhookResult(
    {
      event: {
        type: "EXPIRATION",
        subscriber_id: "user-expired",
        expiration_at_ms: 1_780_120_000_000,
      },
    },
    1_780_121_900
  );

  assert.equal(expiration.ok, true);
  assert.equal(expiration.update.plan, "free");
  assert.equal(expiration.update.subscriptionStatus, "unsubscribed");
  assert.equal(expiration.update.rc.entitlementActive, false);

  const testEvent = buildRevenueCatWebhookResult(
    {
      event: {
        type: "TEST",
        customer_id: "user-test",
      },
    },
    1_780_121_900
  );

  assert.equal(testEvent.ok, true);
  assert.equal(testEvent.appUserId, "user-test");
  assert.equal(testEvent.update.rc.lastWebhookEventType, "TEST");
});

test("RevenueCat webhook parser returns explicit 400s for malformed payloads", () => {
  const missingUser = buildRevenueCatWebhookResult({
    event: {
      type: "RENEWAL",
      expiration_at_ms: 1_780_122_813_000,
    },
  });

  assert.equal(missingUser.ok, false);
  assert.equal(missingUser.status, 400);
  assert.equal(missingUser.error, "Missing RevenueCat app user id");
  assert.equal(missingUser.logContext.eventType, "RENEWAL");
  assert.deepEqual(missingUser.logContext.eventKeys, ["expiration_at_ms", "type"]);
  assert.deepEqual(missingUser.logContext.payloadKeys, ["event"]);

  const missingType = buildRevenueCatWebhookResult({
    event: {
      app_user_id: "user-without-type",
    },
  });

  assert.equal(missingType.ok, false);
  assert.equal(missingType.status, 400);
  assert.equal(missingType.error, "Missing event type");
  assert.equal(missingType.appUserId, "user-without-type");
  assert.deepEqual(missingType.logContext.identifierFields, {
    app_user_id: "user-without-type",
  });
});

test("RevenueCat webhook identifier extraction covers nested, top-level, and alias fields", () => {
  assert.equal(
    extractRevenueCatAppUserId(
      { type: "RENEWAL" },
      { event: { type: "RENEWAL" }, app_user_id: "top-level-user" }
    ),
    "top-level-user"
  );
  assert.equal(
    extractRevenueCatAppUserId(
      { type: "RENEWAL", aliases: ["event-alias"] },
      { aliases: ["payload-alias"] }
    ),
    "event-alias"
  );
  assert.deepEqual(normalizeEvent({ event: { type: "RENEWAL" } }), { type: "RENEWAL" });
});

test("Twilio webhook validation rejects unsigned requests", () => {
  const req = {
    headers: {
      host: "example.cloudfunctions.net",
      "x-forwarded-proto": "https",
    },
    originalUrl: "/twilioInboundSms",
  };

  assert.equal(
    isValidTwilioWebhookRequest(req, "twilio-auth-token", { From: "+15555550100" }),
    false
  );
});

test("Twilio webhook validation accepts a matching request signature", () => {
  const authToken = "twilio-auth-token";
  const params = {
    From: "+15555550100",
    Body: "STOP",
  };
  const req = {
    headers: {
      host: "example.cloudfunctions.net",
      "x-forwarded-proto": "https",
    },
    originalUrl: "/twilioInboundSms",
  };
  const signature = twilio.getExpectedTwilioSignature(authToken, twilioWebhookUrl(req), params);

  assert.equal(
    isValidTwilioWebhookRequest(
      { ...req, headers: { ...req.headers, "x-twilio-signature": signature } },
      authToken,
      params
    ),
    true
  );
});

test("Twilio webhook URL reconstruction uses first forwarded proxy values", () => {
  const req = {
    headers: {
      "x-forwarded-host": "example.cloudfunctions.net, internal.proxy",
      "x-forwarded-proto": "https,http",
    },
    originalUrl: "/twilioInboundSms?foo=bar",
  };

  assert.equal(
    twilioWebhookUrl(req),
    "https://example.cloudfunctions.net/twilioInboundSms?foo=bar"
  );
});

test("SMS eligibility blocks opted-out and inactive users", () => {
  assert.match(
    smsDeliveryBlockReason({ smsOptOut: true, active: true }) ?? "",
    /opted out/
  );
  assert.match(
    smsDeliveryBlockReason({ smsOptOut: false, active: false }) ?? "",
    /disabled/
  );
});

test("SMS eligibility throws before delivery for blocked users", () => {
  assert.throws(
    () => assertSmsDeliveryAllowed({ smsOptOut: true, active: true }),
    (err) => err?.code === "failed-precondition"
  );
  assert.doesNotThrow(() => assertSmsDeliveryAllowed({ smsOptOut: false, active: true }));
});

test("triggerWelcome UID targeting allows self and admin only", () => {
  assert.equal(canTargetUid("user-a", "user-a", {}), true);
  assert.equal(canTargetUid("user-a", "user-b", {}), false);
  assert.equal(canTargetUid("user-a", "user-b", { admin: true }), true);
  assert.equal(canTargetUid("user-a", "user-b", { role: "admin" }), true);
});
