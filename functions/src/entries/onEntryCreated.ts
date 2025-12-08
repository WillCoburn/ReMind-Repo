// ============================
// File: functions/src/entries/onEntryCreated.ts
// ============================
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import {
  MIN_ENTRIES_FOR_SCHEDULING,
  db,
  hasAtLeastEntries,
  scheduleNext,
} from "../config/options";

export const onEntryCreated = onDocumentCreated(
  "users/{uid}/entries/{entryId}",
  async (event) => {
    const uid = event.params.uid as string;

    const user = await db.doc(`users/${uid}`).get();
    if (!user.exists || user.get("active") !== true) return;

    if (await hasAtLeastEntries(uid, MIN_ENTRIES_FOR_SCHEDULING)) {
      await scheduleNext(uid, new Date());
    }
  }
);
