import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);

const {
  resolveServerCapabilities,
  resolveServerCapabilitiesWithRevenueCatEntitlement,
  SERVER_LIMITS,
} = require("../lib/entitlements/capabilities.js");
const {
  fetchRevenueCatSubscriberEntitlement,
  parseRevenueCatV2ActiveEntitlement,
} = require("../lib/revenuecat/customerInfo.js");
const { deriveSubscriptionState } = require("../lib/revenuecat/state.js");

function snap(data) {
  return {
    get(path) {
      return path.split(".").reduce((value, key) => value?.[key], data);
    },
  };
}

test("server capabilities resolve free users to free limits", () => {
  const capabilities = resolveServerCapabilities(snap({ plan: "free" }), 1_000);
  assert.equal(capabilities.plan, "free");
  assert.equal(capabilities.canUseProReminderRange, false);
  assert.equal(capabilities.maxRemindersPerWeek, SERVER_LIMITS.freeMaxRemindersPerWeek);
  assert.equal(capabilities.appliesFreeUsageLimits, true);
});

test("server capabilities resolve active RevenueCat mirror to pro", () => {
  const capabilities = resolveServerCapabilities(
    snap({
      plan: "free",
      rc: { entitlementActive: true, expiresAt: 2_000 },
    }),
    1_000
  );
  assert.equal(capabilities.plan, "pro");
  assert.equal(capabilities.canUseProReminderRange, true);
  assert.equal(capabilities.maxRemindersPerWeek, SERVER_LIMITS.proMaxRemindersPerWeek);
  assert.equal(capabilities.appliesFreeUsageLimits, false);
});

test("server capabilities expose the paid automated reminder cap as 14 per week", () => {
  assert.equal(SERVER_LIMITS.proMaxRemindersPerWeek, 14);

  const capabilities = resolveServerCapabilities(
    snap({
      plan: "free",
      rc: { entitlementActive: true, expiresAt: 2_000 },
    }),
    1_000
  );

  assert.equal(capabilities.maxRemindersPerWeek, 14);
});

test("server capabilities treat expired RevenueCat mirror as free even if plan drifted", () => {
  const capabilities = resolveServerCapabilities(
    snap({
      plan: "pro",
      rc: { entitlementActive: true, expiresAt: 500 },
    }),
    1_000
  );
  assert.equal(capabilities.state, "expired");
  assert.equal(capabilities.plan, "free");
  assert.equal(capabilities.canUseProReminderRange, false);
});

test("server capabilities preserve legacy server-owned pro plan when rc mirror is absent", () => {
  const capabilities = resolveServerCapabilities(snap({ plan: "pro" }), 1_000);
  assert.equal(capabilities.plan, "pro");
  assert.equal(capabilities.canUseProReminderRange, true);
});

test("server capabilities let subscribed server profile bypass stale free RevenueCat mirror", () => {
  const capabilities = resolveServerCapabilities(
    snap({
      plan: "pro",
      subscriptionStatus: "subscribed",
      rc: { entitlementActive: false },
    }),
    1_000
  );
  assert.equal(capabilities.plan, "pro");
  assert.equal(capabilities.source, "serverProfile");
  assert.equal(capabilities.appliesFreeUsageLimits, false);
});

test("server capabilities let active cancelled profile remain pro until expiration", () => {
  const capabilities = resolveServerCapabilities(
    snap({
      plan: "pro",
      subscriptionStatus: "cancelled",
      rc: { entitlementActive: false, expiresAt: 2_000 },
    }),
    1_000
  );
  assert.equal(capabilities.plan, "pro");
  assert.equal(capabilities.appliesFreeUsageLimits, false);
});

test("server capabilities let expired RevenueCat mirror override subscribed profile", () => {
  const capabilities = resolveServerCapabilities(
    snap({
      plan: "pro",
      subscriptionStatus: "subscribed",
      rc: { entitlementActive: true, expiresAt: 500 },
    }),
    1_000
  );
  assert.equal(capabilities.state, "expired");
  assert.equal(capabilities.plan, "free");
  assert.equal(capabilities.appliesFreeUsageLimits, true);
});

test("server capabilities treat webhook delay as free until server mirror says pro", () => {
  const capabilities = resolveServerCapabilities(snap({ plan: "free" }), 1_000);
  assert.equal(capabilities.plan, "free");
  assert.equal(capabilities.appliesFreeUsageLimits, true);
});

test("send-one-now capabilities let fresh RevenueCat Pro bypass stale free quota", () => {
  const staleMirror = snap({
    plan: "free",
    subscriptionStatus: "unsubscribed",
    rc: { entitlementActive: false },
    usage: {
      instantWeekKey: "1970-01-05",
      instantSendsThisWeek: 1,
    },
  });
  const beforeVerification = resolveServerCapabilities(staleMirror, 1_000);
  assert.equal(beforeVerification.plan, "free");
  assert.equal(beforeVerification.appliesFreeUsageLimits, true);

  const revenueCatEntitlement = parseRevenueCatV2ActiveEntitlement(
    {
      items: [{ id: "ent_pro", lookup_key: "pro", display_name: "Pro" }],
    },
    {
      items: [{ entitlement_id: "ent_pro", expires_at: 2_000_000 }],
    },
    "pro",
    1_000
  );
  const afterVerification = resolveServerCapabilitiesWithRevenueCatEntitlement(
    staleMirror,
    revenueCatEntitlement,
    1_000
  );

  assert.equal(afterVerification.plan, "pro");
  assert.equal(afterVerification.source, "revenueCatApi");
  assert.equal(afterVerification.appliesFreeUsageLimits, false);
});

test("revenuecat verification uses v2 active entitlements with secret key", async () => {
  const requestedUrls = [];
  const entitlement = await fetchRevenueCatSubscriberEntitlement(
    "user_123",
    "secret_v2_key",
    "proj_123",
    "pro",
    async (url, options) => {
      requestedUrls.push(String(url));
      assert.equal(options?.headers?.Authorization, "Bearer secret_v2_key");

      if (String(url).endsWith("/projects/proj_123/entitlements?limit=100")) {
        return new Response(
          JSON.stringify({
            items: [{ id: "ent_pro", lookup_key: "pro" }],
          }),
          { status: 200 }
        );
      }

      if (
        String(url).endsWith(
          "/projects/proj_123/customers/user_123/active_entitlements?limit=100"
        )
      ) {
        return new Response(
          JSON.stringify({
            items: [{ entitlement_id: "ent_pro", expires_at: Date.now() + 86_400_000 }],
          }),
          { status: 200 }
        );
      }

      return new Response("unexpected url", { status: 404 });
    }
  );

  assert.equal(entitlement.entitlementActive, true);
  assert.equal(requestedUrls.length, 2);
  assert.ok(requestedUrls.every((url) => url.includes("https://api.revenuecat.com/v2/")));
  assert.ok(requestedUrls.every((url) => !url.includes("/v1/subscribers")));
});

test("revenuecat state keeps cancelled users pro through the paid period", () => {
  const derived = deriveSubscriptionState(
    {
      entitlementActive: true,
      willRenew: false,
      expiresAt: 2_000,
    },
    1_000
  );

  assert.equal(derived.plan, "pro");
  assert.equal(derived.subscriptionStatus, "cancelled");
});

test("revenuecat state expires users after the paid period ends", () => {
  const derived = deriveSubscriptionState(
    {
      entitlementActive: true,
      willRenew: false,
      expiresAt: 500,
    },
    1_000
  );

  assert.equal(derived.plan, "free");
  assert.equal(derived.subscriptionStatus, "unsubscribed");
});
