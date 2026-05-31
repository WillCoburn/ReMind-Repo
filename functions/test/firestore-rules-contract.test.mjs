import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import test from "node:test";

const rulesPath = fileURLToPath(new URL("../../firestore.rules", import.meta.url));
const rules = readFileSync(rulesPath, "utf8");

function safeUserProfileFieldsBody() {
  const match = rules.match(/function\s+safeUserProfileFields\(\)\s*\{[\s\S]*?return\s+\[([\s\S]*?)\];[\s\S]*?\}/);
  assert.ok(match, "safeUserProfileFields() must be present in firestore.rules");
  return match[1];
}

test("user profile writes are allowlisted instead of broad client writes", () => {
  assert.match(
    rules,
    /request\.resource\.data\.keys\(\)\.hasOnly\(safeUserProfileFields\(\)\)/
  );
  assert.match(
    rules,
    /request\.resource\.data\.diff\(resource\.data\)\.affectedKeys\(\)\.hasOnly\(safeUserProfileFields\(\)\)/
  );
});

test("server-owned user fields are not client-writeable", () => {
  const allowlist = safeUserProfileFieldsBody();
  const serverOwnedFields = [
    "plan",
    "rc",
    "usage",
    "active",
    "subscriptionStatus",
    "receivedCount",
    "smsOptOut",
    "trialActive",
    "trialEndsAt",
    "isProUser",
    "isEntitled",
    "revenueCatAppUserId",
    "billing",
    "entitlements",
    "lastSeenAt",
    "autoPausedAt",
    "autoPauseReason",
    "autoPauseNotifiedAt",
    "nextSendAt",
    "automatedSendLockAt",
    "automatedSendLockId",
  ];

  for (const field of serverOwnedFields) {
    assert.equal(
      allowlist.includes(`"${field}"`),
      false,
      `${field} must remain server-owned`
    );
  }
});

test("normal user-controlled profile fields remain client-writeable", () => {
  const allowlist = safeUserProfileFieldsBody();
  for (const field of ["uid", "phoneE164", "createdAt", "updatedAt", "hasSeenFeatureTour"]) {
    assert.equal(allowlist.includes(`"${field}"`), true);
  }
});
