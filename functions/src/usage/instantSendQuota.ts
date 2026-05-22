import { HttpsError } from "firebase-functions/v2/https";
import { db, logger } from "../config/options";

export const FREE_INSTANT_SENDS_PER_WEEK = 1;

export type InstantSendUsage = Record<string, unknown>;

export function instantSendsForWeek(usage: InstantSendUsage, weekKey: string): number {
  const existingWeekKey = String(usage.instantWeekKey ?? "");
  if (existingWeekKey !== weekKey) return 0;

  const sends = Number(usage.instantSendsThisWeek ?? 0);
  return Number.isFinite(sends) ? sends : 0;
}

export function reserveInstantSendUsage(
  usage: InstantSendUsage,
  weekKey: string,
  reservationId: string,
  nowMillis: number
): InstantSendUsage {
  const sendsThisWeek = instantSendsForWeek(usage, weekKey);
  if (sendsThisWeek >= FREE_INSTANT_SENDS_PER_WEEK) {
    throw new HttpsError(
      "resource-exhausted",
      "You already used your weekly instant send, upgrade for unlimited!"
    );
  }

  return {
    ...usage,
    instantWeekKey: weekKey,
    instantSendsThisWeek: sendsThisWeek + 1,
    instantLastReservationId: reservationId,
    instantLastReservationStatus: "reserved",
    instantLastReservationAt: nowMillis,
  };
}

export function markInstantSendReservation(
  usage: InstantSendUsage,
  weekKey: string,
  reservationId: string,
  status: "sent" | "failed",
  nowMillis: number,
  messageSid?: string
): InstantSendUsage {
  if (String(usage.instantWeekKey ?? "") !== weekKey) return usage;
  if (String(usage.instantLastReservationId ?? "") !== reservationId) return usage;

  const nextUsage: InstantSendUsage = {
    ...usage,
    instantLastReservationStatus: status,
    instantLastReservationCompletedAt: nowMillis,
  };

  if (messageSid) {
    nextUsage.instantLastMessageSid = messageSid;
  }

  return nextUsage;
}

export async function reserveFreeInstantSendQuota(
  uid: string,
  weekKey: string,
  reservationId: string,
  nowMillis = Date.now()
): Promise<void> {
  const userRef = db.doc(`users/${uid}`);

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(userRef);
    const usage = (fresh.get("usage") as InstantSendUsage | undefined) ?? {};
    logger.info("[instantSendQuota] reserving free instant send", {
      uid,
      weekKey,
      currentSends: instantSendsForWeek(usage, weekKey),
      usage,
    });
    let nextUsage: InstantSendUsage;
    try {
      nextUsage = reserveInstantSendUsage(usage, weekKey, reservationId, nowMillis);
    } catch (err) {
      logger.warn("[instantSendQuota] free instant send limit hit", {
        uid,
        weekKey,
        currentSends: instantSendsForWeek(usage, weekKey),
      });
      throw err;
    }
    tx.set(userRef, { usage: nextUsage }, { merge: true });
  });
}

export async function markFreeInstantSendReservation(
  uid: string,
  weekKey: string,
  reservationId: string,
  status: "sent" | "failed",
  messageSid?: string,
  nowMillis = Date.now()
): Promise<void> {
  const userRef = db.doc(`users/${uid}`);

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(userRef);
    const usage = (fresh.get("usage") as InstantSendUsage | undefined) ?? {};
    logger.info("[instantSendQuota] marking free instant send reservation", {
      uid,
      weekKey,
      reservationId,
      status,
      currentSends: instantSendsForWeek(usage, weekKey),
    });
    const nextUsage = markInstantSendReservation(
      usage,
      weekKey,
      reservationId,
      status,
      nowMillis,
      messageSid
    );
    tx.set(userRef, { usage: nextUsage }, { merge: true });
  });
}
