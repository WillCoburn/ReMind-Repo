// ============================
// File: functions/src/scheduler/minuteCron.ts
// ============================
import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  admin,
  db,
  logger,
  scheduleNext,
  hasAtLeastEntries,
  MIN_ENTRIES_FOR_SCHEDULING,
  pickEntry,
  incrementReceivedCount,
  recordLastReminder,
  applyOptOut,
  isTwilioStopError,
  TWILIO_SID,
  TWILIO_AUTH,
  TWILIO_FROM,
  TWILIO_MSID,
} from "../config/options";
import { getTwilioClient, buildMsgParams, sendSMS } from "../twilio/client";
import { resolveServerCapabilities } from "../entitlements/capabilities";
import {
  INACTIVITY_AUTO_PAUSE_NOTICE_TEXT,
  shouldAutoPauseAutomatedReminders,
} from "../inactivity/policy";
import { reserveInactivityAutoPause } from "../inactivity/schedulerPause";
import { parseRcExpiresAt } from "../revenuecat/state";
import { smsDeliveryBlockReason } from "../sms/eligibility";

export const minuteCron = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "UTC",
    secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID],
  },
  async () => {
    logger.info("[minuteCron] boot v1");

    const sid = TWILIO_SID.value();
    const token = TWILIO_AUTH.value();
    const from = TWILIO_FROM.value();
    const msid = TWILIO_MSID.value();
    const client = getTwilioClient(sid, token);

    const now = admin.firestore.Timestamp.now();
    const nowSeconds = now.seconds + now.nanoseconds / 1_000_000_000;

    logger.info("[minuteCron] querying due users");
    const dueSnap = await db
      .collection("users")
      .where("active", "==", true)
      .where("nextSendAt", "<=", now)
      .limit(100)
      .get();
    logger.info("[minuteCron] due count", { count: dueSnap.size });

    if (dueSnap.empty) return;

    for (const doc of dueSnap.docs) {
      const uid = doc.id;
      const to = doc.get("phoneE164") as string | undefined;
      const blockReason = smsDeliveryBlockReason(doc);

      if (blockReason) {
        logger.warn("[minuteCron] skipping SMS-blocked user", { uid, blockReason });
        await db.doc(`users/${uid}`).set(
          {
            active: false,
            nextSendAt: null,
          },
          { merge: true }
        );
        continue;
      }

      if (!to) {
        await scheduleNext(uid, new Date());
        continue;
      }

      try {
        const { expiresAt, expiresAtSeconds: rcExpiresAtSeconds, needsNormalization } = parseRcExpiresAt(
          doc.get("rc.expiresAt")
        );

        if (needsNormalization && expiresAt) {
          await doc.ref.set({ rc: { expiresAt } }, { merge: true });
          logger.info("[minuteCron] normalized rc.expiresAt", { uid, rcExpiresAtSeconds });
        }

        if (rcExpiresAtSeconds != null && rcExpiresAtSeconds < nowSeconds) {
          logger.warn("[minuteCron] skipping expired user", { uid, rcExpiresAtSeconds });
          await db.doc(`users/${uid}`).set(
            {
              rc: { entitlementActive: false, willRenew: false },
              // Tier migration: expired paid users become free (not locked out).
              // Keep `active` for operational SMS gating only.
              plan: "free",
              subscriptionStatus: "unsubscribed",
            },
            { merge: true }
          );
        }

        const freshUserSnap = await db.doc(`users/${uid}`).get();
        const freshBlockReason = smsDeliveryBlockReason(freshUserSnap);
        if (freshBlockReason) {
          logger.warn("[minuteCron] skipping freshly SMS-blocked user", { uid, freshBlockReason });
          await db.doc(`users/${uid}`).set(
            {
              active: false,
              nextSendAt: null,
            },
            { merge: true }
          );
          continue;
        }

        if (doc.get("welcomed") !== true) {
          await (async () => {
            const params = buildMsgParams({
              to,
              body: "Welcome to ReMind! Reply STOP to opt out or HELP for help.",
              from,
              msid,
            });
            try {
              await sendSMS(client, params);
            } catch (err: any) {
              if (isTwilioStopError(err)) {
                await applyOptOut(uid);
              }
              throw err;
            }
            await db.doc(`users/${uid}`).set(
              {
                welcomed: true,
                welcomedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          })();
          await scheduleNext(uid, new Date());
          continue;
        }

        const freshCapabilities = resolveServerCapabilities(freshUserSnap, nowSeconds);
        if (
          shouldAutoPauseAutomatedReminders(
            freshUserSnap,
            freshCapabilities,
            now.toMillis()
          )
        ) {
          const pauseReservation = await reserveInactivityAutoPause(uid, now, nowSeconds);
          if (pauseReservation.paused) {
            logger.info("[minuteCron] auto-paused inactive non-paying user", {
              uid,
              alreadyPaused: pauseReservation.alreadyPaused,
              noticeReserved: pauseReservation.shouldSendNotice,
            });

            if (pauseReservation.shouldSendNotice && pauseReservation.to) {
              const params = buildMsgParams({
                to: pauseReservation.to,
                body: INACTIVITY_AUTO_PAUSE_NOTICE_TEXT,
                from,
                msid,
              });

              try {
                const res = await sendSMS(client, params);
                logger.info("[minuteCron] sent inactivity auto-pause notice", {
                  uid,
                  messageSid: res?.sid,
                });
              } catch (noticeErr: any) {
                if (isTwilioStopError(noticeErr)) {
                  await applyOptOut(uid);
                }
                logger.warn("[minuteCron] failed to send inactivity auto-pause notice", {
                  uid,
                  message: noticeErr?.message,
                  code: noticeErr?.code ?? null,
                  status: noticeErr?.status ?? null,
                });
              }
            }

            continue;
          }
        }

        if (!(await hasAtLeastEntries(uid, MIN_ENTRIES_FOR_SCHEDULING))) {
          await db.doc(`users/${uid}`).set({ nextSendAt: null }, { merge: true });
          continue;
        }

        const picked = await pickEntry(uid);
        const body = picked?.body;
        if (!body) {
          await scheduleNext(uid, new Date());
          continue;
        }

        const msgParams = buildMsgParams({ to, body, from, msid });

        let res: any;
        try {
          res = await sendSMS(client, msgParams);
        } catch (err: any) {
          if (isTwilioStopError(err)) {
            await applyOptOut(uid);
            continue;
          }
          throw err;
        }

        const resCode = res?.errorCode != null ? String(res.errorCode) : "";
        const resFailed =
          resCode === "21610" ||
          (typeof res?.status === "string" && res.status.toLowerCase() === "failed");

        if (resFailed) {
          await applyOptOut(uid);
          continue;
        }

        try {
          await recordLastReminder(uid, body, {
            entryRef: picked.ref,
            deliveredVia: "auto",
            messageSid: res?.sid,
          });
        } catch (lastReminderErr: any) {
          logger.warn("[minuteCron] failed to record lastReminder", {
            uid,
            message: lastReminderErr?.message,
          });
        }

        try {
          if (picked?.ref) {
            await picked.ref.update({
              sent: true,
              sentAt: admin.firestore.FieldValue.serverTimestamp(),
              deliveredVia: "auto",
              scheduledFor: null,
            });
          }
        } catch (markErr: any) {
          logger.warn("[minuteCron] failed to mark entry sent", {
            uid,
            message: markErr?.message,
          });
        }

        try {
          await incrementReceivedCount(uid);
        } catch (metricErr: any) {
          logger.warn("[minuteCron] failed to increment receivedCount", {
            uid,
            message: metricErr?.message,
          });
        }

        await scheduleNext(uid, new Date());
      } catch (e: any) {
        logger.error(
          "[minuteCron] send failed details " +
            JSON.stringify({
              uid,
              message: e?.message ?? String(e),
              code: e?.code ?? null,
              status: e?.status ?? null,
              moreInfo: e?.moreInfo ?? null,
            })
        );
        await scheduleNext(uid, new Date());
      }
    }
  }
);
