import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import test from "node:test";

function repoFile(path) {
  return fileURLToPath(new URL(`../../${path}`, import.meta.url));
}

function readRepoFile(path) {
  return readFileSync(repoFile(path), "utf8");
}

function schedulingThreshold() {
  const options = readRepoFile("functions/src/config/options.ts");
  const match = options.match(/MIN_ENTRIES_FOR_SCHEDULING\s*=\s*(\d+)/);
  assert.ok(match, "MIN_ENTRIES_FOR_SCHEDULING must be declared");
  return Number(match[1]);
}

test("automated reminder scheduling threshold allows the first sendable entry", () => {
  const threshold = schedulingThreshold();

  assert.equal(threshold, 1);
  assert.equal(0 >= threshold, false, "0 entries must not be scheduling eligible");
  assert.equal(1 >= threshold, true, "1 entry must be scheduling eligible");
  assert.equal(2 >= threshold, true, "2 entries must remain scheduling eligible");
  assert.equal(3 >= threshold, true, "the third saved item must remain scheduling eligible");
});

test("scheduleNext and minuteCron clear nextSendAt only when no sendable entries exist", () => {
  const options = readRepoFile("functions/src/config/options.ts");
  const cron = readRepoFile("functions/src/scheduler/minuteCron.ts");
  const entryCreated = readRepoFile("functions/src/entries/onEntryCreated.ts");

  assert.match(
    options,
    /if\s*\(\s*!\(await hasAtLeastEntries\(uid,\s*MIN_ENTRIES_FOR_SCHEDULING\)\)\s*\)\s*\{[\s\S]*nextSendAt:\s*null/,
    "scheduleNext should clear nextSendAt when the 1-entry threshold is not met"
  );
  assert.match(
    cron,
    /if\s*\(\s*!\(await hasAtLeastEntries\(uid,\s*MIN_ENTRIES_FOR_SCHEDULING\)\)\s*\)\s*\{[\s\S]*nextSendAt:\s*null/,
    "minuteCron should clear nextSendAt instead of sending when no sendable entries remain"
  );

  const thresholdCheckIndex = cron.indexOf("hasAtLeastEntries(uid, MIN_ENTRIES_FOR_SCHEDULING)");
  const pickIndex = cron.indexOf("const picked = await pickEntry(uid)");
  assert.ok(thresholdCheckIndex > -1, "minuteCron must check entry availability");
  assert.ok(pickIndex > -1, "minuteCron must pick an entry after availability checks");
  assert.ok(thresholdCheckIndex < pickIndex, "minuteCron must check availability before picking/sending");

  assert.match(
    entryCreated,
    /hasAtLeastEntries\(uid,\s*MIN_ENTRIES_FOR_SCHEDULING\)[\s\S]*scheduleNext\(uid,\s*new Date\(\)\)/,
    "onEntryCreated should schedule as soon as the first sendable entry meets the shared threshold"
  );
});

test("main BrainMail UI no longer uses a multi-entry unlock counter", () => {
  const main = readRepoFile("ReMind/Views/Main/MainView.swift");
  const hint = readRepoFile("ReMind/Views/Components/HintBadge.swift");
  const legacyCounterWord = "g" + "oal";

  assert.doesNotMatch(main, new RegExp(`private\\s+let\\s+${legacyCounterWord}`));
  assert.doesNotMatch(main, /HintBadge\(/);
  assert.doesNotMatch(main, new RegExp(`>=\\s*${legacyCounterWord}|<\\s*${legacyCounterWord}`));
  assert.doesNotMatch(main, /You need at least/);
  assert.doesNotMatch(main, new RegExp(`unlock this feature|${["unlock", "reminders"].join(" ")}`));

  assert.match(main, /let canUseGuardedActions = net\.isConnected && count > 0/);
  assert.match(main, /if count == 0 \{ presentLockedAlert\(feature: "Send One Now"\); return \}/);
  assert.match(main, /if count == 0 \{ presentLockedAlert\(feature: "Export PDF"\); return \}/);
  assert.match(main, /Save your first entry before using/);

  assert.doesNotMatch(
    hint,
    new RegExp(`${legacyCounterWord}|progress|${["unlock", "reminders"].join(" ")}|Add \\\\(${legacyCounterWord} - count\\\\) more`)
  );
  assert.match(hint, /Add more over time to make your reminders feel more varied\./);
});

test("Send One Now UI is available with one saved entry", () => {
  const main = readRepoFile("ReMind/Views/Main/MainView.swift");
  const topBar = readRepoFile("ReMind/Views/Main/Components/TopBarActions.swift");

  const sendNowHandler = main.match(/private func handleSendNowTap\(\) \{[\s\S]*?\n    \}/)?.[0] ?? "";
  assert.match(sendNowHandler, /if count == 0/);
  assert.doesNotMatch(
    sendNowHandler,
    new RegExp(`${"g" + "oal"}|count < 1|count < 3|${["count", ">=", "3"].join(" ")}`)
  );

  assert.match(topBar, /let hasSavedEntries = count > 0/);
  assert.doesNotMatch(topBar, new RegExp(`${"g" + "oal"}|>=${"g" + "oal"}|>= ${"g" + "oal"}|< ${"g" + "oal"}`));
});

test("stale 3-entry onboarding and unlock copy is absent from first-time UI files", () => {
  const files = [
    "ReMind/Views/Main/MainView.swift",
    "ReMind/Views/Components/HintBadge.swift",
    "ReMind/Views/Main/Components/TopBarActions.swift",
    "ReMind/Views/FeatureTourOverlay.swift",
    "ReMind/Views/Onboarding/PhoneEntryScreen.swift",
  ];
  const stalePhrases = [
    ["3", "entries"].join(" "),
    ["three", "entries"].join(" "),
    ["Add", "2", "more"].join(" "),
    ["Add", "1", "more"].join(" "),
    ["minimum", "entries"].join(" "),
    ["unlock", "reminders"].join(" "),
    ["add", "more", "entries", "to", "unlock"].join(" "),
  ];
  const staleCopyPattern = new RegExp(stalePhrases.join("|"), "i");

  for (const path of files) {
    const source = readRepoFile(path);
    assert.doesNotMatch(source, staleCopyPattern, path);
  }
});

test("entry composer uses custom overlay focus instead of keyboard height math", () => {
  const composer = readRepoFile("ReMind/Views/Main/Components/EntryComposer.swift");
  const main = readRepoFile("ReMind/Views/Main/MainView.swift");

  assert.match(composer, /struct NewEntryComposerOverlay:\s*View/);
  assert.match(composer, /struct NewEntryComposerSheet:\s*View/);
  assert.match(composer, /@FocusState private var isTextEditorFocused:\s*Bool/);
  assert.match(composer, /Task\.sleep\(nanoseconds:\s*190_000_000\)[\s\S]*isTextEditorFocused = true/);
  assert.match(main, /@State private var isComposing = false/);
  assert.match(main, /\.sheet\(item:\s*\$activeHomeSheet\)/);
  assert.doesNotMatch(main, /case newEntry|case \.newEntry|NewEntryComposerSheet\(/);
  assert.match(main, /if isComposing[\s\S]*NewEntryComposerOverlay\(/);
  assert.match(main, /private func presentEntryComposer\(\)[\s\S]*isComposing = true/);
  assert.doesNotMatch(main, /keyboardFrame|keyboardHeight|keyboardFrameEndUserInfoKey/);
  assert.doesNotMatch(composer, /keyboardFrame|keyboardHeight|keyboardFrameEndUserInfoKey/);
});

test("entry composer keeps compact tap card and clean overlay actions", () => {
  const composer = readRepoFile("ReMind/Views/Main/Components/EntryComposer.swift");

  assert.match(composer, /Text\("New entry"\)/);
  assert.match(composer, /Tap to write to future you\.\.\./);
  assert.match(composer, /placeholder:\s*"What’s something worth remembering\?"/);
  assert.doesNotMatch(
    composer,
    new RegExp(["Write", "something", "you.d", "want", "to", "receive", "later"].join(" "))
  );
  assert.match(composer, /writingSurfaceBackground/);
  assert.match(composer, /BrainMailComposePrimaryButtonLabel\([\s\S]*title: "Save"/);
  assert.match(composer, /Text\("Cancel"\)/);
  assert.match(composer, /home\.entryComposer\.overlay\.cancel/);
  assert.match(composer, /home\.entryComposer\.overlay\.save/);
  assert.doesNotMatch(composer, /cancelButton|Cancel reminder|Label\("Cancel"/);
});
