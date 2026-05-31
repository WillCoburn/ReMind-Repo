import { timingSafeEqual } from "node:crypto";
import twilio from "twilio";

type HeaderValue = string | string[] | undefined;
type HeaderMap = Record<string, HeaderValue>;

type RequestLike = {
  headers: HeaderMap;
  protocol?: string;
  originalUrl?: string;
  url?: string;
  get?: (name: string) => string | undefined;
};

function headerValue(headers: HeaderMap, name: string): string | undefined {
  const exact = headers[name] ?? headers[name.toLowerCase()];
  const raw =
    exact ??
    headers[
      Object.keys(headers).find((key) => key.toLowerCase() === name.toLowerCase()) ?? ""
    ];
  if (Array.isArray(raw)) return raw[0];
  return raw;
}

function constantTimeEqual(lhs: string, rhs: string): boolean {
  const lhsBuffer = Buffer.from(lhs);
  const rhsBuffer = Buffer.from(rhs);
  if (lhsBuffer.length !== rhsBuffer.length) return false;
  return timingSafeEqual(lhsBuffer, rhsBuffer);
}

export function isValidRevenueCatWebhook(headers: HeaderMap, expectedAuth: string): boolean {
  const configured = expectedAuth.trim();
  if (!configured) return false;

  const authorization = headerValue(headers, "authorization")?.trim();
  if (!authorization) return false;

  if (authorization.length === configured.length && constantTimeEqual(authorization, configured)) {
    return true;
  }

  const bearerMatch = authorization.match(/^Bearer\s+(.+)$/i);
  const bearerToken = bearerMatch?.[1]?.trim();
  if (!bearerToken) return false;

  return constantTimeEqual(bearerToken, configured);
}

function requestHost(req: RequestLike): string {
  const forwardedHost = headerValue(req.headers, "x-forwarded-host");
  const host = forwardedHost ?? req.get?.("host") ?? headerValue(req.headers, "host");
  return host?.split(",")[0]?.trim() ?? "";
}

function requestProtocol(req: RequestLike): string {
  const forwardedProto = headerValue(req.headers, "x-forwarded-proto");
  return (forwardedProto?.split(",")[0]?.trim() || req.protocol || "https").replace(/:$/, "");
}

export function twilioWebhookUrl(req: RequestLike): string {
  return `${requestProtocol(req)}://${requestHost(req)}${req.originalUrl ?? req.url ?? ""}`;
}

export function isValidTwilioWebhookRequest(
  req: RequestLike,
  authToken: string,
  params: Record<string, unknown>
): boolean {
  const configured = authToken.trim();
  if (!configured) return false;

  const signature = headerValue(req.headers, "x-twilio-signature");
  if (!signature) return false;

  try {
    return twilio.validateRequest(
      configured,
      signature,
      twilioWebhookUrl(req),
      params as Record<string, string>
    );
  } catch {
    return false;
  }
}
