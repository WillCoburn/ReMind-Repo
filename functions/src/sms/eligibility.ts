import { HttpsError } from "firebase-functions/v2/https";

type UserDataLike =
  | FirebaseFirestore.DocumentSnapshot
  | Record<string, unknown>
  | null
  | undefined;

function fieldValue(user: UserDataLike, field: string): unknown {
  if (!user) return undefined;
  if ("get" in user && typeof user.get === "function") {
    return user.get(field);
  }
  return (user as Record<string, unknown>)[field];
}

export function smsDeliveryBlockReason(user: UserDataLike): string | null {
  if (fieldValue(user, "smsOptOut") === true) {
    return "SMS delivery is disabled because this user has opted out.";
  }

  if (fieldValue(user, "active") === false) {
    return "SMS delivery is disabled for this user.";
  }

  return null;
}

export function assertSmsDeliveryAllowed(user: UserDataLike): void {
  const reason = smsDeliveryBlockReason(user);
  if (!reason) return;
  throw new HttpsError("failed-precondition", reason);
}
