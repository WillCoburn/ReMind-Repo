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
  applyOptOut,
  isTwilioStopError,
  TWILIO_SID,
  TWILIO_AUTH,
  TWILIO_FROM,
  TWILIO_MSID,
} from "../config/options";
import { getTwilioClient, buildMsgParams, sendSMS } from "../twilio/client";

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

      if (!to) {
        await scheduleNext(uid, new Date());
        continue;
      }

      try {
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

        await db.doc(`users/${uid}`).set({ active: true, smsOptOut: false }, { merge: true });

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
