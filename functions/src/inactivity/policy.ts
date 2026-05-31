import type { ServerCapabilities } from "../entitlements/capabilities";

export const INACTIVITY_AUTO_PAUSE_DAYS = 28;
export const INACTIVITY_AUTO_PAUSE_REASON = "inactive_user";
const LEGACY_INACTIVITY_AUTO_PAUSE_REASON = "inactive_non_paying_user";
export const INACTIVITY_AUTO_PAUSE_NOTICE_TEXT =
  "Your BrainMail reminders have been paused due to inactivity. Open the app anytime to resume them. Reply STOP to opt out permanently.";

type SnapshotLike = {
  get(fieldPath: string): unknown;
};

type UserDataLike = SnapshotLike | Record<string, unknown> | null | undefined;

function fieldValue(user: UserDataLike, fieldPath: string): unknown {
  if (!user) return undefined;
  if ("get" in user && typeof user.get === "function") {
    return user.get(fieldPath);
  }

  return fieldPath.split(".").reduce<unknown>((value, key) => {
    if (value == null || typeof value !== "object") return undefined;
    return (value as Record<string, unknown>)[key];
  }, user);
}

export function timestampMillis(raw: unknown): number | null {
  if (raw == null) return null;
  if (raw instanceof Date) return raw.getTime();
  if (typeof raw === "number") return Number.isFinite(raw) ? raw : null;
  if (typeof raw === "string") {
    const asNumber = Number(raw);
    if (Number.isFinite(asNumber)) return asNumber;
    const asDate = Date.parse(raw);
    return Number.isFinite(asDate) ? asDate : null;
  }

  if (typeof raw === "object") {
    const value = raw as {
      toMillis?: () => number;
      seconds?: number;
      nanoseconds?: number;
      _seconds?: number;
      _nanoseconds?: number;
    };
    if (typeof value.toMillis === "function") {
      const millis = value.toMillis();
      return Number.isFinite(millis) ? millis : null;
    }

    const seconds = value.seconds ?? value._seconds;
    const nanoseconds = value.nanoseconds ?? value._nanoseconds ?? 0;
    if (typeof seconds === "number" && Number.isFinite(seconds)) {
      return seconds * 1000 + nanoseconds / 1_000_000;
    }
  }

  return null;
}

export function isValidE164Phone(raw: unknown): raw is string {
  return typeof raw === "string" && /^\+[1-9]\d{1,14}$/.test(raw);
}

export function isInactiveForAutomatedReminders(
  user: UserDataLike,
  nowMillis = Date.now(),
  inactivityDays = INACTIVITY_AUTO_PAUSE_DAYS
): boolean {
  const lastSeenMillis = timestampMillis(fieldValue(user, "lastSeenAt"));
  if (lastSeenMillis == null) return true;

  const inactiveCutoffMillis = nowMillis - inactivityDays * 24 * 60 * 60 * 1000;
  return lastSeenMillis <= inactiveCutoffMillis;
}

export function shouldAutoPauseAutomatedReminders(
  user: UserDataLike,
  capabilities: Pick<ServerCapabilities, "plan">,
  nowMillis = Date.now()
): boolean {
  if (fieldValue(user, "smsOptOut") === true) return false;
  if (String(capabilities.plan).toLowerCase() === "pro") return false;

  return isInactiveForAutomatedReminders(user, nowMillis);
}

export function hasInactivityAutoPause(user: UserDataLike): boolean {
  const reason = fieldValue(user, "autoPauseReason");
  return (
    (reason === INACTIVITY_AUTO_PAUSE_REASON ||
      reason === LEGACY_INACTIVITY_AUTO_PAUSE_REASON) &&
    fieldValue(user, "autoPausedAt") != null
  );
}

export function shouldReserveInactivityPauseNotice(user: UserDataLike): boolean {
  if (fieldValue(user, "smsOptOut") === true) return false;
  if (!isValidE164Phone(fieldValue(user, "phoneE164"))) return false;

  return fieldValue(user, "autoPauseNotifiedAt") == null;
}

export function shouldClearInactivityAutoPauseOnActivity(user: UserDataLike): boolean {
  return fieldValue(user, "smsOptOut") !== true && hasInactivityAutoPause(user);
}
