type CallableToken = Record<string, unknown> | undefined;

function truthyClaim(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") return value.toLowerCase() === "true";
  if (typeof value === "number") return value === 1;
  return false;
}

export function hasAdminTargetingClaim(token: CallableToken): boolean {
  return truthyClaim(token?.admin) || token?.role === "admin";
}

export function canTargetUid(
  callerUid: string | undefined,
  targetUid: string,
  token: CallableToken
): boolean {
  if (!callerUid) return false;
  if (targetUid === callerUid) return true;
  return hasAdminTargetingClaim(token);
}
