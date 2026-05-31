import { resolveServerCapabilities } from "../entitlements/capabilities";
import { admin, db } from "../config/options";
import {
  INACTIVITY_AUTO_PAUSE_REASON,
  hasInactivityAutoPause,
  isValidE164Phone,
  shouldAutoPauseAutomatedReminders,
  shouldReserveInactivityPauseNotice,
} from "./policy";

export type InactivityAutoPauseReservation = {
  paused: boolean;
  alreadyPaused: boolean;
  shouldSendNotice: boolean;
  to: string | null;
};

export async function reserveInactivityAutoPause(
  uid: string,
  now: admin.firestore.Timestamp,
  nowSeconds = now.toMillis() / 1000
): Promise<InactivityAutoPauseReservation> {
  const userRef = db.doc(`users/${uid}`);
  const nowMillis = now.toMillis();

  let reservation: InactivityAutoPauseReservation = {
    paused: false,
    alreadyPaused: false,
    shouldSendNotice: false,
    to: null,
  };

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) return;

    const capabilities = resolveServerCapabilities(snap, nowSeconds);
    if (!shouldAutoPauseAutomatedReminders(snap, capabilities, nowMillis)) {
      return;
    }

    const alreadyPaused = hasInactivityAutoPause(snap);
    const rawPhone = snap.get("phoneE164");
    const to = isValidE164Phone(rawPhone) ? rawPhone : null;
    const shouldSendNotice = shouldReserveInactivityPauseNotice(snap);
    const update: Record<string, unknown> = {
      autoPauseReason: INACTIVITY_AUTO_PAUSE_REASON,
      nextSendAt: null,
      automatedSendLockAt: admin.firestore.FieldValue.delete(),
      automatedSendLockId: admin.firestore.FieldValue.delete(),
    };

    if (!alreadyPaused) {
      update.autoPausedAt = now;
    }

    if (shouldSendNotice) {
      update.autoPauseNotifiedAt = now;
    }

    tx.set(userRef, update, { merge: true });

    reservation = {
      paused: true,
      alreadyPaused,
      shouldSendNotice,
      to,
    };
  });

  return reservation;
}
