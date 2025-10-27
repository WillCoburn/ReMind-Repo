import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import twilio from "twilio";

const TWILIO_SID = defineSecret("TWILIO_SID");
const TWILIO_AUTH_TOKEN = defineSecret("TWILIO_AUTH_TOKEN");
const TWILIO_FROM = defineSecret("TWILIO_FROM");

export const twilioSecrets = [TWILIO_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM];

export interface SendSmsPayload {
  to: string;
  body: string;
}

export async function sendSms(payload: SendSmsPayload): Promise<void> {
  const { to, body } = payload;
  const [sid, token, from] = await Promise.all([
    TWILIO_SID.value(),
    TWILIO_AUTH_TOKEN.value(),
    TWILIO_FROM.value(),
  ]);

  if (!sid || !token || !from) {
    throw new Error("Twilio secrets are not configured");
  }

  const client = twilio(sid, token);

  try {
    const result = await client.messages.create({
      to,
      from,
      body,
    });
    logger.info("Sent SMS with PDF link", { sid: result.sid, to });
  } catch (error: any) {
    logger.error("Failed to send SMS", {
      to,
      message: error?.message,
      code: error?.code,
      status: error?.status,
    });
    throw error;
  }
}
