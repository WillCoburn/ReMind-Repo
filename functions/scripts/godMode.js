#!/usr/bin/env node
// ============================
// File: functions/scripts/godMode.js
// ============================
const admin = require("firebase-admin");

async function main() {
  const [, , uid, stateArg] = process.argv;
  if (!uid) {
    console.error("Usage: npm run godmode -- <firebase-uid> [on|off]");
    process.exit(1);
  }

  const enable = (stateArg || "on").toLowerCase() !== "off";

  if (admin.apps.length === 0) {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }

  const auth = admin.auth();
  const user = await auth.getUser(uid);
  const currentClaims = user.customClaims || {};

  const nextClaims = { ...currentClaims, godMode: enable };
  await auth.setCustomUserClaims(uid, nextClaims);

  console.log(`God mode ${enable ? "enabled" : "disabled"} for ${uid}`);
}

main().catch((err) => {
  console.error("Failed to toggle god mode:", err);
  process.exit(1);
});
