// ============================
// File: functions/src/entries/onEntryCreated.ts
// ============================
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db, hasAtLeastEntries, scheduleNext } from "../config/options";

export const onEntryCreated = onDocumentCreated(
  "users/{uid}/entries/{entryId}",
  async (event) => {
    const uid = event.params.uid as string;

    const user = await db.doc(`users/${uid}`).get();
    if (!user.exists || user.get("active") !== true) return;

    if (await hasAtLeastEntries(uid, 10)) {
      await scheduleNext(uid, new Date());
    }
  }
);
