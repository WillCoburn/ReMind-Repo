import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);

const {
  reserveInstantSendUsage,
  markInstantSendReservation,
} = require("../lib/usage/instantSendQuota.js");
const {
  normalizeReminderSettings,
} = require("../lib/settings/reminders.js");
const { SERVER_LIMITS } = require("../lib/entitlements/capabilities.js");

test("free instant-send reservation consumes the weekly slot before SMS", () => {
  const reserved = reserveInstantSendUsage({}, "2026-05-18", "reservation-a", 1_000);

  assert.equal(reserved.instantWeekKey, "2026-05-18");
  assert.equal(reserved.instantSendsThisWeek, 1);
  assert.equal(reserved.instantLastReservationStatus, "reserved");

  assert.throws(
    () => reserveInstantSendUsage(reserved, "2026-05-18", "reservation-b", 2_000),
    (err) => err?.code === "resource-exhausted"
  );
});

test("failed instant-send reservation remains consumed to avoid duplicate SMS", () => {
  const reserved = reserveInstantSendUsage({}, "2026-05-18", "reservation-a", 1_000);
  const failed = markInstantSendReservation(
    reserved,
    "2026-05-18",
    "reservation-a",
    "failed",
    2_000
  );

  assert.equal(failed.instantSendsThisWeek, 1);
  assert.equal(failed.instantLastReservationStatus, "failed");
  assert.throws(
    () => reserveInstantSendUsage(failed, "2026-05-18", "reservation-b", 3_000),
    (err) => err?.code === "resource-exhausted"
  );
});

test("successful instant-send reservation records the Twilio message without double counting", () => {
  const reserved = reserveInstantSendUsage({}, "2026-05-18", "reservation-a", 1_000);
  const sent = markInstantSendReservation(
    reserved,
    "2026-05-18",
    "reservation-a",
    "sent",
    2_000,
    "SM123"
  );

  assert.equal(sent.instantSendsThisWeek, 1);
  assert.equal(sent.instantLastReservationStatus, "sent");
  assert.equal(sent.instantLastMessageSid, "SM123");
});

test("free reminder settings clamp to backend free limits", () => {
  const normalized = normalizeReminderSettings(
    {
      remindersPerWeek: 20,
      tzIdentifier: "America/New_York",
      quietStartHour: -4,
      quietEndHour: 99,
    },
    {
      plan: "free",
      maxRemindersPerWeek: SERVER_LIMITS.freeMaxRemindersPerWeek,
    }
  );

  assert.equal(normalized.remindersPerWeek, SERVER_LIMITS.freeMaxRemindersPerWeek);
  assert.equal(normalized.quietStartHour, 0);
  assert.equal(normalized.quietEndHour, 24);
  assert.equal(normalized.wasClamped, true);
});

test("pro reminder settings allow the same max as the client pro capability", () => {
  const normalized = normalizeReminderSettings(
    {
      remindersPerWeek: 20,
      tzIdentifier: "America/Los_Angeles",
      quietStartHour: 8,
      quietEndHour: 21,
    },
    {
      plan: "pro",
      maxRemindersPerWeek: SERVER_LIMITS.proMaxRemindersPerWeek,
    }
  );

  assert.equal(normalized.remindersPerWeek, SERVER_LIMITS.proMaxRemindersPerWeek);
  assert.equal(normalized.wasClamped, false);
});
