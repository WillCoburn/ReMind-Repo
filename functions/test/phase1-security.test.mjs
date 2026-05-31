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
