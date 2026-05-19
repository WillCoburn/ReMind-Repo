import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);

const {
  resolveServerCapabilities,
  SERVER_LIMITS,
} = require("../lib/entitlements/capabilities.js");

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

test("server capabilities treat webhook delay as free until server mirror says pro", () => {
  const capabilities = resolveServerCapabilities(snap({ plan: "free" }), 1_000);
  assert.equal(capabilities.plan, "free");
  assert.equal(capabilities.appliesFreeUsageLimits, true);
});
