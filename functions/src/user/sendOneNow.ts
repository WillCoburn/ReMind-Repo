// ============================
// File: functions/src/user/sendOneNow.ts
// ============================
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  admin,
  db,
  logger,
  applyOptOut,
  isTwilioStopError,
  pickEntry,
  incrementReceivedCount,
  recordLastReminder,
  TWILIO_SID,
  TWILIO_AUTH,
  TWILIO_FROM,
  TWILIO_MSID,
  resolvePlan,
} from "../config/options";
import { getTwilioClient, buildMsgParams, sendSMS } from "../twilio/client";
import { enforceMonthlyLimit } from "../usageLimits";

function startOfWeekKeyInTimeZone(now: Date, tzIdentifier: string): string {
  // Monday-start calendar week in user's local timezone.
  const localDate = new Date(now.toLocaleString("en-US", { timeZone: tzIdentifier }));
  const day = localDate.getDay(); // 0 = Sunday
  const diffToMonday = day === 0 ? -6 : 1 - day;
  localDate.setHours(0, 0, 0, 0);
  localDate.setDate(localDate.getDate() + diffToMonday);
  const y = localDate.getFullYear();
  const m = String(localDate.getMonth() + 1).padStart(2, "0");
  const d = String(localDate.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function twilioHttpsError(err: any) {
  const details = {
    provider: "twilio",
    status: err?.status,
    code: err?.code,
    moreInfo: err?.moreInfo,
    message: err?.message,
  };
  logger.error("[sendOneNow] Twilio error", details);
  return new HttpsError(
    "failed-precondition",
    `Twilio ${details.code ?? ""} ${details.message ?? "send failed"}`.trim(),
    details
  );
}

export const sendOneNow = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID], invoker: "public" },
  async (req) => {
    try {
      const uid = req.auth?.uid;
      if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

      // Get recipient phone
      const userSnap = await db.doc(`users/${uid}`).get();
      if (!userSnap.exists) throw new HttpsError("not-found", "User not found.");
      const to = userSnap.get("phoneE164") as string | undefined;
      if (!to) throw new HttpsError("failed-precondition", "No phone number on file.");

      const plan = resolvePlan(userSnap);

      // Pro behavior remains unchanged, including the hidden monthly cap.
      if (plan === "pro") {
        await enforceMonthlyLimit(uid, "manualSendsThisMonth", 50);
      }

      const settingsSnap = await db.doc(`users/${uid}/meta/settings`).get();
      const tzIdentifier = String(settingsSnap.get("tzIdentifier") ?? "UTC");
      const weekKey = startOfWeekKeyInTimeZone(new Date(), tzIdentifier);

      if (plan === "free") {
        const usage = (userSnap.get("usage") as Record<string, unknown> | undefined) ?? {};
        const existingWeekKey = String(usage.instantWeekKey ?? "");
        const existingSends = Number(usage.instantSendsThisWeek ?? 0);
        const sendsThisWeek = existingWeekKey === weekKey ? existingSends : 0;
        if (sendsThisWeek >= 1) {
          throw new HttpsError(
            "resource-exhausted",
            "You already used your weekly instant send, upgrade for unlimited!"
          );
        }
      }

      // Pick entry
      const picked = await pickEntry(uid);
      const body = picked?.body;
      if (!body) throw new HttpsError("failed-precondition", "No entries available.");

      // Send via Twilio
      const sid = TWILIO_SID.value();
      const token = TWILIO_AUTH.value();
      const from = TWILIO_FROM.value();
      const msid = TWILIO_MSID.value();
      const client = getTwilioClient(sid, token);

      const params = buildMsgParams({ to, body, from, msid });
      const res = await sendSMS(client, params);
      logger.info("[sendOneNow] sent", { messageSid: res.sid });

      try {
        await recordLastReminder(uid, body, {
          entryRef: picked.ref,
          deliveredVia: "manual",
          messageSid: res.sid,
        });
      } catch (lastReminderErr: any) {
        logger.warn("[sendOneNow] failed to record lastReminder", {
          uid,
          message: lastReminderErr?.message,
        });
      }

      // Mark matching unsent entry as sent (best-effort)
      try {
        if (picked?.ref) {
          await picked.ref.update({
            sent: true,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            deliveredVia: "sms",
            scheduledFor: null,
          });
        } else {
          logger.info("[sendOneNow] no matching unsent entry to mark as sent", { uid });
        }
      } catch (markErr: any) {
        logger.warn("[sendOneNow] failed to mark entry sent", {
          uid,
          message: markErr?.message,
        });
      }

      try {
        await incrementReceivedCount(uid);
      } catch (metricErr: any) {
        logger.warn("[sendOneNow] failed to increment receivedCount", {
          uid,
          message: metricErr?.message,
        });
      }

      if (plan === "free") {
        // Increment ONLY after successful Twilio send.
        await db.runTransaction(async (tx) => {
          const fresh = await tx.get(db.doc(`users/${uid}`));
          const usage = (fresh.get("usage") as Record<string, unknown> | undefined) ?? {};
          const existingWeekKey = String(usage.instantWeekKey ?? "");
          const existingSends = Number(usage.instantSendsThisWeek ?? 0);
          const sendsThisWeek = existingWeekKey === weekKey ? existingSends : 0;

          tx.set(
            db.doc(`users/${uid}`),
            {
              usage: {
                ...usage,
                instantWeekKey: weekKey,
                instantSendsThisWeek: sendsThisWeek + 1,
              },
            },
            { merge: true }
          );
        });
      }

      return { ok: true, messageSid: res.sid };
    } catch (err: any) {
      if (err instanceof HttpsError) {
        throw err;
      }
      if (isTwilioStopError(err)) {
        const uid = req.auth?.uid as string | undefined;
        if (uid) await applyOptOut(uid);
      }
      if (err?.moreInfo || err?.code || err?.status) throw twilioHttpsError(err);
      throw new HttpsError("internal", err?.message ?? "Unknown error");
    }
  }
);
