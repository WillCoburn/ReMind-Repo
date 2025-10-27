import * as admin from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { generatePdf } from "../generatePdf";
import { sendSms, twilioSecrets } from "../sendSms";

const db = admin.firestore();

const TEN_MINUTES_MS = 10 * 60 * 1000;

interface RawEntry {
  text?: unknown;
  createdAt?: unknown;
}

function toDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value === "number") {
    return new Date(value);
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return null;
}

function normalisePhoneNumber(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (trimmed.startsWith("+")) {
    return trimmed;
  }
  const digits = trimmed.replace(/\D/g, "");
  if (digits.length === 10) {
    return `+1${digits}`;
  }
  if (digits.length > 10 && digits.startsWith("1")) {
    return `+${digits}`;
  }
  return null;
}

async function resolveUserPhone(uid: string, token: Record<string, unknown> | undefined) {
  const authPhone = normalisePhoneNumber((token?.phone_number as string | undefined) ?? null);
  if (authPhone) {
    return authPhone;
  }

  const userDoc = await db.doc(`users/${uid}`).get();
  if (userDoc.exists) {
    const direct = normalisePhoneNumber((userDoc.get("phoneE164") as string | undefined) ?? null);
    if (direct) {
      return direct;
    }
    const digits = normalisePhoneNumber((userDoc.get("profile.phoneDigits") as string | undefined) ?? null);
    if (digits) {
      return digits;
    }
  }

  return null;
}

async function fetchEntries(uid: string) {
  const userEntriesSnap = await db
    .collection("users")
    .doc(uid)
    .collection("entries")
    .orderBy("createdAt", "asc")
    .get();

  if (!userEntriesSnap.empty) {
    return userEntriesSnap.docs
      .map((doc) => doc.data() as RawEntry)
      .filter((data) => typeof data.text === "string")
      .map((data) => ({
        text: data.text as string,
        createdAt: toDate(data.createdAt),
      }));
  }

  const topLevelSnap = await db
    .collection("entries")
    .where("userId", "==", uid)
    .get();

  if (topLevelSnap.empty) {
    return [] as { text: string; createdAt: Date | null }[];
  }

  const fallbackEntries = topLevelSnap.docs
    .map((doc) => doc.data() as RawEntry & { userId?: unknown })
    .filter((data) => typeof data.text === "string")
    .map((data) => ({
      text: data.text as string,
      createdAt: toDate(data.createdAt),
    }));

  return fallbackEntries.sort((a, b) => {
    const aTime = a.createdAt ? a.createdAt.getTime() : 0;
    const bTime = b.createdAt ? b.createdAt.getTime() : 0;
    return aTime - bTime;
  });
}

export const exportHistoryPdf = onCall({ secrets: [...twilioSecrets] }, async (request) => {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be signed in to export history.");
  }

  logger.info("exportHistoryPdf invoked", { uid });

  const userPhone = await resolveUserPhone(uid, request.auth?.token);
  if (!userPhone) {
    logger.warn("exportHistoryPdf missing phone", { uid });
    return { success: false, errorMessage: "No phone on file." };
  }

  const cooldownRef = db.doc(`users/${uid}/meta/exportCooldown`);
  const now = Date.now();
  const cooldownSnap = await cooldownRef.get();
  const lastSentAt = cooldownSnap.exists
    ? toDate(cooldownSnap.get("lastSentAt"))?.getTime()
    : undefined;

  if (lastSentAt && now - lastSentAt < TEN_MINUTES_MS) {
    const remaining = Math.ceil((TEN_MINUTES_MS - (now - lastSentAt)) / 60000);
    const message = `Please wait about ${remaining} more minute${remaining === 1 ? "" : "s"} before exporting again.`;
    logger.warn("exportHistoryPdf rate limited", { uid, lastSentAt });
    return { success: false, errorMessage: message };
  }

  const entries = await fetchEntries(uid);
  if (entries.length === 0) {
    return { success: false, errorMessage: "No entries found to export." };
  }

  logger.info("exportHistoryPdf compiling entries", { uid, entryCount: entries.length });

  try {
    const displayName =
      (request.auth?.token?.name as string | undefined) ||
      (await (async () => {
        const userRecord = await admin.auth().getUser(uid).catch(() => null);
        return userRecord?.displayName ?? null;
      })());

    const { signedUrl } = await generatePdf({
      uid,
      entries,
      displayName,
      phoneNumber: userPhone,
    });

    const body = `Your ReMind history PDF is ready: ${signedUrl}\nLink expires in 24 hours.`;
    await sendSms({ to: userPhone, body });

    await cooldownRef.set({ lastSentAt: Timestamp.now() }, { merge: true });

    logger.info("exportHistoryPdf completed", { uid });

    return { success: true, mediaUrl: signedUrl };
  } catch (error: any) {
    logger.error("exportHistoryPdf failed", {
      uid,
      message: error?.message,
      stack: error?.stack,
    });
    return { success: false, errorMessage: "Unable to export right now. Please try again later." };
  }
});
