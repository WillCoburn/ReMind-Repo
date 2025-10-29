// ============================
// File: functions/src/index.ts
// ============================

// ensure global options + admin init + secrets are registered
import "./config/options";

// callables (user)
export { sendOneNow } from "./user/sendOneNow";
export { applyUserSettings } from "./user/applyUserSettings";

// onboarding
export { triggerWelcome } from "./onboarding/triggerWelcome";

// scheduler
export { minuteCron } from "./scheduler/minuteCron";

// firestore triggers
export { onEntryCreated } from "./entries/onEntryCreated";

// twilio webhooks
export { twilioInboundSms, twilioStatusCallback } from "./twilio/webhooks";

// (exports features are defined in their own files)
// export { getExportUploadUrl } from "./exports/getExportUploadUrl";
// export { sendExportLink } from "./exports/sendExportLink";
