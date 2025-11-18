// ============================
// File: functions/src/config/godMode.ts
// ============================
import type { CallableRequest } from "firebase-functions/v2/https";

type CallableAuth = CallableRequest["auth"];

export function isGodMode(auth: CallableAuth | undefined): boolean {
  const raw = auth?.token?.godMode;
  if (typeof raw === "boolean") {
    return raw;
  }
  if (typeof raw === "string") {
    return raw.toLowerCase() === "true";
  }
  if (typeof raw === "number") {
    return raw === 1;
  }
  return false;
}
