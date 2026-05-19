import { SERVER_LIMITS, ServerCapabilities, ServerPlan } from "../entitlements/capabilities";

export const MIN_REMINDERS_PER_WEEK = 1;

export type ReminderSettingsInput = {
  remindersPerWeek?: unknown;
  remindersPerDay?: unknown;
  tzIdentifier?: unknown;
  quietStartHour?: unknown;
  quietEndHour?: unknown;
};

export type NormalizedReminderSettings = {
  remindersPerWeek: number;
  tzIdentifier: string;
  quietStartHour: number;
  quietEndHour: number;
  wasClamped: boolean;
};

function finiteNumber(raw: unknown): number | null {
  const value = typeof raw === "string" ? Number(raw) : Number(raw);
  return Number.isFinite(value) ? value : null;
}

export function maxRemindersPerWeekForPlan(plan: ServerPlan): number {
  return plan === "pro"
    ? SERVER_LIMITS.proMaxRemindersPerWeek
    : SERVER_LIMITS.freeMaxRemindersPerWeek;
}

export function normalizeReminderSettings(
  input: ReminderSettingsInput,
  capabilities: Pick<ServerCapabilities, "plan" | "maxRemindersPerWeek">
): NormalizedReminderSettings {
  const maxRemindersPerWeek = Math.min(
    SERVER_LIMITS.proMaxRemindersPerWeek,
    Math.max(
      MIN_REMINDERS_PER_WEEK,
      capabilities.maxRemindersPerWeek ?? maxRemindersPerWeekForPlan(capabilities.plan)
    )
  );
  const rawWeekly =
    finiteNumber(input.remindersPerWeek) ??
    (finiteNumber(input.remindersPerDay) != null
      ? finiteNumber(input.remindersPerDay)! * 7
      : SERVER_LIMITS.freeMaxRemindersPerWeek);
  const roundedWeekly = Math.round(rawWeekly);
  const remindersPerWeek = Math.min(
    maxRemindersPerWeek,
    Math.max(MIN_REMINDERS_PER_WEEK, roundedWeekly)
  );

  const rawStart = finiteNumber(input.quietStartHour) ?? 9;
  const rawEnd = finiteNumber(input.quietEndHour) ?? 22;
  const quietStartHour = Math.min(24, Math.max(0, Math.round(rawStart)));
  const quietEndHour = Math.min(24, Math.max(0, Math.round(rawEnd)));
  const rawTz = typeof input.tzIdentifier === "string" ? input.tzIdentifier.trim() : "";
  const tzIdentifier = rawTz || "UTC";

  return {
    remindersPerWeek,
    tzIdentifier,
    quietStartHour,
    quietEndHour,
    wasClamped:
      remindersPerWeek !== rawWeekly ||
      quietStartHour !== rawStart ||
      quietEndHour !== rawEnd ||
      tzIdentifier !== input.tzIdentifier,
  };
}
