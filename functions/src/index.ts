// ============================
// File: functions/src/index.ts
// ============================

// 👇 Ensure Admin SDK + globals are initialized exactly once
import "./config/options";

// Re-export the handlers you want deployed
export { sendOneNow } from "./user/sendOneNow";
export { applyUserSettings } from "./user/applyUserSettings";
export { triggerWelcome } from "./onboarding/triggerWelcome";
export { minuteCron } from "./scheduler/minuteCron";
export { onEntryCreated } from "./entries/onEntryCreated";
export { twilioStatusCallback, twilioInboundSms } from "./twilio/webhooks";
export { getExportUploadUrl } from "./exports/getExportUploadUrl";
export { sendExportLink } from "./exports/sendExportLink";
