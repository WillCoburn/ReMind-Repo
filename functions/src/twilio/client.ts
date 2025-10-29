// ============================
// File: twilio/client.ts
// ============================

import Twilio, { Twilio as TwilioClient } from "twilio";

/** Creates and returns a Twilio client */
export function getTwilioClient(sid: string, auth: string): TwilioClient {
  if (!sid || !auth) throw new Error("Twilio secrets not set.");
  return Twilio(sid, auth);
}

/** Send an SMS via Twilio */
export async function sendSMS(client: TwilioClient, params: any) {
  return client.messages.create(params as any);
}

/** Build message parameters from provided options */
export function buildMsgParams(opts: {
  to: string;
  body: string;
  from?: string | null;
  msid?: string | null;
}) {
  const { to, body, from, msid } = opts;
  return msid
    ? { to, body, messagingServiceSid: msid }
    : { to, body, from: from as string };
}
