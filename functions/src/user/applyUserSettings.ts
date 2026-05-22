// ============================
// File: functions/src/user/applyUserSettings.ts
// ============================
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { admin, db, logger, scheduleNext, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID, TWILIO_SID } from "../config/options";
import { resolveServerCapabilities } from "../entitlements/capabilities";
import { normalizeReminderSettings } from "../settings/reminders";

function clientRevision(data: unknown): number | null {
  const raw = (data as Record<string, unknown> | undefined)?.clientRevision;
  const value = typeof raw === "string" ? Number(raw) : Number(raw);
  return Number.isFinite(value) ? value : null;
}

export const applyUserSettings = onCall(
  { secrets: [TWILIO_SID, TWILIO_AUTH, TWILIO_FROM, TWILIO_MSID], invoker: "public" },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

    const userSnap = await db.doc(`users/${uid}`).get();
    if (!userSnap.exists) throw new HttpsError("not-found", "User not found.");

    const settingsRef = db.doc(`users/${uid}/meta/settings`);
    const requestedSettings = req.data?.settings as Record<string, unknown> | undefined;
    const requestedRevision = clientRevision(req.data);
    const capabilities = resolveServerCapabilities(userSnap);
    logger.info("[applyUserSettings] resolved capabilities", {
      uid,
      plan: capabilities.plan,
      state: capabilities.state,
      source: capabilities.source,
      reason: capabilities.reason,
      maxRemindersPerWeek: capabilities.maxRemindersPerWeek,
    });

    await db.runTransaction(async (tx) => {
      const currentSnap = await tx.get(settingsRef);
      const existing = currentSnap.exists ? currentSnap.data() ?? {} : {};
      const existingRevision = clientRevision(existing);

      if (
        requestedRevision != null &&
        existingRevision != null &&
        requestedRevision < existingRevision
      ) {
        return;
      }

      const normalized = normalizeReminderSettings(requestedSettings ?? existing, capabilities);
      const { wasClamped: _wasClamped, ...settingsWrite } = normalized;
      tx.set(
        settingsRef,
        {
          ...settingsWrite,
          clientRevision: requestedRevision ?? existingRevision ?? Date.now(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    await scheduleNext(uid, new Date());
    return { ok: true };
  }
);
