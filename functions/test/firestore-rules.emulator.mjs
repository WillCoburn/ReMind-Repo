import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";

const rulesPath = fileURLToPath(new URL("../../firestore.rules", import.meta.url));
const rules = readFileSync(rulesPath, "utf8");

test("users cannot write server-owned fields on their profile doc", async (t) => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "Run with `npm run test:rules`.");

  const testEnv = await initializeTestEnvironment({
    projectId: "demo-remind",
    firestore: { rules },
  });
  t.after(async () => testEnv.cleanup());

  const aliceDb = testEnv.authenticatedContext("alice").firestore();
  const aliceProfile = doc(aliceDb, "users/alice");

  await assertSucceeds(
    setDoc(aliceProfile, {
      uid: "alice",
      phoneE164: "+15555550100",
      createdAt: new Date(),
      updatedAt: new Date(),
    })
  );

  await assertFails(setDoc(aliceProfile, { plan: "pro" }, { merge: true }));
  await assertFails(setDoc(aliceProfile, { rc: { entitlementActive: true } }, { merge: true }));
  await assertFails(setDoc(aliceProfile, { usage: { sendOneNow: 0 } }, { merge: true }));
  await assertFails(setDoc(aliceProfile, { active: true }, { merge: true }));
  await assertFails(setDoc(aliceProfile, { subscriptionStatus: "active" }, { merge: true }));
  await assertFails(setDoc(aliceProfile, { receivedCount: 0 }, { merge: true }));

  await assertSucceeds(
    setDoc(doc(aliceDb, "users/alice/meta/settings"), { remindersPerWeek: 3 })
  );

  const bobDb = testEnv.authenticatedContext("bob").firestore();
  await assertFails(setDoc(doc(bobDb, "users/alice"), { phoneE164: "+15555550101" }));
});
