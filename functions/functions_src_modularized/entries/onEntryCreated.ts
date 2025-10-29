// ============================
// File: entries/onEntryCreated.ts
// ============================

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

export const onEntryCreated = onDocumentCreated("users/{uid}/entries/{entryId}", async (event) => {
  logger.info("[onEntryCreated] triggered", { uid: event.params.uid });
});
