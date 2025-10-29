// ============================
// File: functions/src/twilio/webhooks.ts
// ============================
import { onRequest } from "firebase-functions/v2/https";
import {
  db,
  logger,
  STOP_KEYWORDS,
  START_KEYWORDS,
  findUserByPhone,
  applyOptOut,
  applyOptIn,
} from "../config/options";

function parseTwilioPayload(req: any) {
  const contentType = (req.headers["content-type"] || "").toString();

  if (contentType.includes("application/json")) {
    return (req.body ?? {}) as Record<string, any>;
  }

  if (req.body && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
    return req.body as Record<string, any>;
  }

  const raw = req.rawBody ? req.rawBody.toString("utf8") : "";
  const params = new URLSearchParams(raw);
  const data: Record<string, any> = {};
  params.forEach((value, key) => {
    data[key] = value;
  });
  return data;
}

function normalizeKeyword(body: string) {
  return body.trim().toUpperCase();
}

function escapeXml(text: string) {
  return text.replace(/[<>&"']/g, (ch) => {
    switch (ch) {
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case "&":
        return "&amp;";
      case '"':
        return "&quot;";
      case "'":
        return "&apos;";
      default:
        return ch;
    }
  });
}

async function handleStopForPhone(phone: string) {
  const userDoc = await findUserByPhone(phone);
  if (!userDoc) {
    logger.warn("[twilioWebhook] STOP received but no user matched", { phone });
    return false;
  }
  await applyOptOut(userDoc.id);
  logger.warn("[twilioWebhook] user opted out", { uid: userDoc.id, phone });
  return true;
}

async function handleStartForPhone(phone: string) {
  const userDoc = await findUserByPhone(phone);
  if (!userDoc) {
    logger.warn("[twilioWebhook] START received but no user matched", { phone });
    return false;
  }
  await applyOptIn(userDoc.id);
  logger.info("[twilioWebhook] user re-subscribed", { uid: userDoc.id, phone });
  return true;
}

export const twilioStatusCallback = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const payload = parseTwilioPayload(req);
  const to = (payload.To || payload.to || "").toString();
  const errorCode = (payload.ErrorCode || payload.errorCode || "").toString();

  if (errorCode === "21610" && to) {
    await handleStopForPhone(to);
  }

  res.status(200).send("OK");
});

export const twilioInboundSms = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const payload = parseTwilioPayload(req);
  const from = (payload.From || payload.from || "").toString();
  const body = (payload.Body || payload.body || "").toString();

  if (!from) {
    res.status(200).set("Content-Type", "text/xml").send("<Response></Response>");
    return;
  }

  const keyword = normalizeKeyword(body);
  let message: string | null = null;
  let handled = false;

  if (STOP_KEYWORDS.has(keyword)) {
    handled = await handleStopForPhone(from);
    message = "You have been unsubscribed from ReMind messages.";
  } else if (START_KEYWORDS.has(keyword)) {
    handled = await handleStartForPhone(from);
    message = "You have been re-subscribed to ReMind messages.";
  }

  const responseBody =
    handled && message
      ? `<Response><Message>${escapeXml(message)}</Message></Response>`
      : "<Response></Response>";

  res.status(200).set("Content-Type", "text/xml").send(responseBody);
});
