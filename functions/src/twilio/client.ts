// ============================
// File: functions/src/twilio/client.ts
// ============================
import Twilio, { Twilio as TwilioClient } from "twilio";

export type MsgParams =
  | { to: string; body: string; from: string }
  | { to: string; body: string; messagingServiceSid: string };

export function getTwilioClient(sid: string, auth: string): TwilioClient {
  if (!sid || !auth) throw new Error("Twilio secrets not set.");
  return Twilio(sid, auth);
}

export async function sendSMS(client: TwilioClient, params: MsgParams) {
  return client.messages.create(params as any);
}

export function buildMsgParams(opts: {
  to: string;
  body: string;
  from?: string | null;
  msid?: string | null;
}): MsgParams {
  const { to, body, from, msid } = opts;
  return msid
    ? { to, body, messagingServiceSid: msid }
    : { to, body, from: from as string };
}
