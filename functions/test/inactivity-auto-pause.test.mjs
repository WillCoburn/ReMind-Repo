import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);

const {
  INACTIVITY_AUTO_PAUSE_DAYS,
  INACTIVITY_AUTO_PAUSE_NOTICE_TEXT,
  INACTIVITY_AUTO_PAUSE_REASON,
  hasInactivityAutoPause,
  shouldAutoPauseAutomatedReminders,
  shouldClearInactivityAutoPauseOnActivity,
  shouldReserveInactivityPauseNotice,
} = require("../lib/inactivity/policy.js");
const {
  assertSmsDeliveryAllowed,
} = require("../lib/sms/eligibility.js");

const dayMillis = 24 * 60 * 60 * 1000;
const nowMillis = Date.parse("2026-05-20T12:00:00Z");
const freeCapabilities = { plan: "free" };
const proCapabilities = { plan: "pro" };

function timestamp(millis) {
  return { toMillis: () => millis };
}

test("free inactive users are auto-paused and receive one pause notice reservation", () => {
  const user = {
    active: true,
    smsOptOut: false,
    phoneE164: "+15555550100",
    lastSeenAt: timestamp(nowMillis - (INACTIVITY_AUTO_PAUSE_DAYS + 1) * dayMillis),
  };

  assert.equal(
    shouldAutoPauseAutomatedReminders(user, freeCapabilities, nowMillis),
    true
  );
  assert.equal(shouldReserveInactivityPauseNotice(user), true);
  assert.equal(
    INACTIVITY_AUTO_PAUSE_NOTICE_TEXT,
    "Your BrainMail reminders have been paused due to inactivity. Open the app anytime to resume them. Reply STOP to opt out permanently."
  );
});

test("inactive users already notified in the current cycle are skipped without another notice", () => {
  const user = {
    active: true,
    smsOptOut: false,
    phoneE164: "+15555550100",
    lastSeenAt: timestamp(nowMillis - (INACTIVITY_AUTO_PAUSE_DAYS + 5) * dayMillis),
    autoPausedAt: timestamp(nowMillis - dayMillis),
    autoPauseReason: INACTIVITY_AUTO_PAUSE_REASON,
    autoPauseNotifiedAt: timestamp(nowMillis - dayMillis),
  };

  assert.equal(
    shouldAutoPauseAutomatedReminders(user, freeCapabilities, nowMillis),
    true
  );
  assert.equal(hasInactivityAutoPause(user), true);
  assert.equal(shouldReserveInactivityPauseNotice(user), false);
});

test("app activity clears inactivity pause for users who have not opted out", () => {
  const pausedUser = {
    smsOptOut: false,
    autoPausedAt: timestamp(nowMillis - dayMillis),
    autoPauseReason: INACTIVITY_AUTO_PAUSE_REASON,
    autoPauseNotifiedAt: timestamp(nowMillis - dayMillis),
  };
  const activeAgainUser = {
    smsOptOut: false,
    phoneE164: "+15555550100",
    lastSeenAt: timestamp(nowMillis),
  };

  assert.equal(shouldClearInactivityAutoPauseOnActivity(pausedUser), true);
  assert.equal(
    shouldAutoPauseAutomatedReminders(activeAgainUser, freeCapabilities, nowMillis),
    false
  );
});

test("a later inactivity cycle can reserve a new pause notice after reactivation", () => {
  const user = {
    active: true,
    smsOptOut: false,
    phoneE164: "+15555550100",
    lastSeenAt: timestamp(nowMillis - (INACTIVITY_AUTO_PAUSE_DAYS + 2) * dayMillis),
  };

  assert.equal(
    shouldAutoPauseAutomatedReminders(user, freeCapabilities, nowMillis),
    true
  );
  assert.equal(shouldReserveInactivityPauseNotice(user), true);
});

test("pro users are not auto-paused by inactivity", () => {
  const user = {
    active: true,
    smsOptOut: false,
    phoneE164: "+15555550100",
    lastSeenAt: timestamp(nowMillis - (INACTIVITY_AUTO_PAUSE_DAYS + 10) * dayMillis),
  };

  assert.equal(
    shouldAutoPauseAutomatedReminders(user, proCapabilities, nowMillis),
    false
  );
});

test("smsOptOut users do not receive pause notices and are not auto-resumed", () => {
  const user = {
    active: false,
    smsOptOut: true,
    phoneE164: "+15555550100",
    lastSeenAt: timestamp(nowMillis - (INACTIVITY_AUTO_PAUSE_DAYS + 10) * dayMillis),
    autoPausedAt: timestamp(nowMillis - dayMillis),
    autoPauseReason: INACTIVITY_AUTO_PAUSE_REASON,
  };

  assert.equal(
    shouldAutoPauseAutomatedReminders(user, freeCapabilities, nowMillis),
    false
  );
  assert.equal(shouldReserveInactivityPauseNotice(user), false);
  assert.equal(shouldClearInactivityAutoPauseOnActivity(user), false);
});

test("manual and transactional SMS eligibility is not blocked by auto-pause fields", () => {
  assert.doesNotThrow(() =>
    assertSmsDeliveryAllowed({
      active: true,
      smsOptOut: false,
      autoPausedAt: timestamp(nowMillis - dayMillis),
      autoPauseReason: INACTIVITY_AUTO_PAUSE_REASON,
      autoPauseNotifiedAt: timestamp(nowMillis - dayMillis),
    })
  );
});

test("pause notices are not reserved for missing or invalid phone numbers", () => {
  assert.equal(
    shouldReserveInactivityPauseNotice({
      smsOptOut: false,
      phoneE164: "",
    }),
    false
  );
  assert.equal(
    shouldReserveInactivityPauseNotice({
      smsOptOut: false,
      phoneE164: "555-555-0100",
    }),
    false
  );
});
