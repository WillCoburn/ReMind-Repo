# BrainMail AI Context Deep Dive

This document is for future AI/coding agents working in the BrainMail codebase. It summarizes the current product, architecture, main flows, backend responsibilities, and recent pitfalls so new work can start from the actual system rather than rediscovering it.

## What BrainMail Is

BrainMail is an iOS app that lets people save short thoughts, encouragements, insights, and reminders for their future selves. The app later sends those saved entries back to the user as SMS messages at randomized supportive times.

The core emotional product is simple: a user captures a note now, then BrainMail resurfaces it later through text message delivery. SMS is central to the product because it arrives outside the app, feels personal, and can reach users at moments when they may not open a wellness app.

The project was originally called ReMind in code and bundle identifiers. Product copy now uses BrainMail in most user-facing surfaces.

## Main User Flows

- Onboarding: user enters a phone number, agrees to receive texts, completes SMS code verification, and gets a Firebase Auth session.
- Main screen: user sees the most recent received reminder, adds new entries to their private bank, opens Send One Now, exports, help, and the Inspiration Bank.
- New entry: the compact home card animates through a short ghost expansion into a native compose sheet and saves through `AppViewModel.submit(text:)`.
- Automatic reminders: backend scheduling picks sendable entries and sends them by SMS according to user settings.
- Send One Now: user manually triggers one SMS reminder immediately through a callable Cloud Function.
- Community: user reads short uplifting posts, creates a community note, likes, reports, opens threads, and replies.
- Inspiration Bank: user browses curated entries and toggles them into or out of their private reminder bank.
- Settings/right panel: user changes reminder frequency, quiet hours, time zone, subscription, background, support, community guidelines, logout, and account deletion.
- Subscription: user buys or restores Pro through RevenueCat/paywall UI. Fresh post-purchase or post-restore RevenueCat customer info unlocks Pro UI immediately while the backend/webhook catches up.

## Freemium And Subscription Model

The app has one paid tier: Pro. There is no multi-plan picker.

Current limits are centralized around `SubscriptionLimits` on the client and `SERVER_LIMITS` on the backend:

- Free automatic reminder cap: 3 reminders per week.
- Pro automatic reminder cap: 14 reminders per week.
- Free instant send cap: 1 instant send per week.
- Pro instant sends: free usage limit should be bypassed.
- Export SMS links have a free monthly quota enforced server-side; Pro bypasses that free quota.

Important client files:

- `ReMind/Models/UserProfile.swift`: `UserPlan`, `SubscriptionState`, `SubscriptionLimits`, and `SubscriptionCapabilities`.
- `ReMind/ViewModels/AppViewModel/AppViewModel.swift`: effective subscription state, capability helpers, fresh RevenueCat Pro override, usage gate logging.
- `ReMind/Payment/RevenueCatManager.swift`: RevenueCat SDK setup, customer info refresh/restore, entitlement helper, management URL.
- `ReMind/Payment/SubscriptionSheet.swift`: RevenueCat paywall and restore/purchase UI handling.
- `ReMind/Views/Settings/Sections/SubscriptionSection.swift`: settings subscription summary and restore affordance.

Backend subscription files:

- `functions/src/revenuecat/webhook.ts`: webhook that mirrors RevenueCat entitlement data into `users/{uid}.rc`, `plan`, and `subscriptionStatus`.
- `functions/src/revenuecat/state.ts`: derives plan/status from RevenueCat data.
- `functions/src/entitlements/capabilities.ts`: server-side plan/capability resolver.
- `functions/src/scheduler/reconcileRevenueCatEntitlements.ts`: scheduled reconciliation path.

Source-of-truth note:

- RevenueCat customer info is purchase truth immediately after purchase/restore.
- Firestore/webhook mirror remains authoritative for backend enforcement.
- Client UI should use fresh active RevenueCat customer info as a temporary Pro state until Firestore catches up.
- Do not unlock backend-only behavior from stale local cache. For user-facing UI, use `AppViewModel.subscriptionCapabilities`.

## SMS Reminder Functionality

SMS delivery is the app's main differentiator. Entries are not just stored; they are routed to the user as future text messages.

Key backend responsibilities:

- `functions/src/scheduler/minuteCron.ts`: scheduled function that finds due users, checks SMS eligibility, resolves subscription capabilities, picks an entry, sends via Twilio, records last reminder, marks entries sent, increments `receivedCount`, and schedules the next send.
- `functions/src/config/options.ts`: shared Firebase admin setup, Twilio secrets, scheduling helpers, entry picking, opt-out helpers, and settings normalization.
- `functions/src/twilio/client.ts`: Twilio client/message parameter helpers.
- `functions/src/twilio/webhooks.ts`: inbound STOP/START/HELP handling and status callbacks.
- `functions/src/sms/eligibility.ts`: central SMS delivery block checks.
- `functions/src/onboarding/triggerWelcome.ts`: welcome/onboarding SMS path.

SMS opt-out matters:

- Twilio STOP or equivalent provider errors set `smsOptOut` and usually set `active` false.
- START/UNSTOP should opt the user back in and schedule next reminders.
- `active` is now best understood as operational SMS enablement, not subscription tier.

## Community Page

The Community page is a lightweight shared feed for uplifting or meaningful notes from real users. It is intentionally separate from private BrainMail entries.

Client files:

- `ReMind/Views/Community/CommunityView.swift`: feed, loading/empty/error states, optimistic like/report state, block handling, thread presentation.
- `ReMind/Views/Community/CommunityComposerSheet.swift`: native sheet for posting a community note.
- `ReMind/Views/Community/CommunityPostRow.swift`: feed row UI.
- `ReMind/Utils/CommunityAPI.swift`: Firestore listeners and callable wrappers.
- `ReMind/Views/FeatureTourOverlay.swift`: includes `CommunityTourIllustration`, reused in onboarding/feature tour and community empty/loading states.

Backend community functions in `functions/src/index.ts`:

- `createCommunityPost`
- `toggleCommunityLike`
- `createCommunityComment`
- `toggleCommunityCommentLike`
- `toggleCommunityCommentReport`
- `toggleCommunityReport`

Moderation basics:

- Posts and comments expire after 7 days.
- Client writes for community content are blocked by Firestore rules; Cloud Functions own create/update behavior.
- Users can report posts and comments.
- Report spam is limited.
- Hidden content should not be shown in normal feed/listener results.
- God mode/dev users can bypass some limits or interact differently for testing/moderation.

## Inspiration Bank / Saved Entries

The Inspiration Bank is a curated set of suggested reminders grouped by category. Users can add suggestions into their private bank, and the checkmark button can toggle them back out.

Key file:

- `ReMind/Views/Sheets/InspirationBankSheet.swift`

Important behavior:

- Adding an inspiration item calls `AppViewModel.addEntryToBank`.
- Removing an added/already-present item calls `AppViewModel.softDeleteReminderFromBank`.
- Local sets `addedReminderIDs`, `removedReminderIDs`, and `busyReminderIDs` provide optimistic UI and prevent rapid-tap races.
- Duplicate detection uses normalized text through `AppViewModel.hasActiveEntryMatching`.

## Main Screen Architecture

Main screen file:

- `ReMind/Views/Main/MainView.swift`

Important supporting components:

- `ReMind/Views/Main/Components/EntryComposer.swift`
- `ReMind/Views/Main/Components/TopBarActions.swift`
- `ReMind/Views/Main/Components/OfflineBanner.swift`
- `ReMind/Views/Main/Components/TrialBanner.swift`
- `ReMind/Views/Sheets/SendNowSheet.swift`
- `ReMind/Views/Sheets/ExportSheet.swift`
- `ReMind/Views/Sheets/InspirationBankSheet.swift`

Current new-entry behavior:

- The home screen shows a compact "New entry" card.
- Tapping it briefly expands an anchored, noninteractive ghost of the home card before presenting `NewEntryComposerSheet`.
- The actual editor lives in the native sheet for stable system keyboard behavior; the ghost carries no focus or input state.
- The sheet fades its surface in and requests editor focus after presentation begins, so the keyboard does not lead the transition.
- Cancel or interactive sheet dismissal clears the draft and removes any ghost presentation state.
- Save calls the existing `AppViewModel.submit(text:)` path.
- Normal SwiftUI viewport resizing and scrolling handle the keyboard; the composer deliberately avoids custom keyboard offset math.

Recent caution:

- Previous direct sheet, floating overlay, inline editing, and custom full-screen experiments each had tradeoffs. Keep the short ghost-to-native-sheet bridge and avoid custom keyboard-height-driven layout or competing focus systems.

## Settings / Stats / Right Panel

Right panel file:

- `ReMind/Views/RightPanel/RightPanelPlaceholderView.swift`

Older settings panel:

- `ReMind/Views/Settings/UserSettingsPanel.swift`

The root app uses a horizontal page layout:

- Left: Community
- Center: Main
- Right: settings/stats panel

Root/navigation files:

- `ReMind/Views/RootView.swift`
- `ReMind/Views/Home/HomePagerView.swift`

Right panel responsibilities:

- Reminder frequency slider
- Quiet window
- Time zone
- Subscription state/CTA
- Contact/support
- Community guidelines link
- Logout/delete account
- Stats such as received count and streak-related surfaces

Reminder settings:

- Client stores values in `UserDefaults` for immediate UI.
- Backend persists normalized settings in `users/{uid}/meta/settings`.
- `applyUserSettings` callable normalizes limits by server-resolved capabilities.
- Free users should not be able to persist Pro-range reminder settings.

## Onboarding And Phone Auth

Key files:

- `ReMind/Views/Onboarding/OnboardingView.swift`
- `ReMind/Views/Onboarding/PhoneEntryScreen.swift`
- `ReMind/Views/Onboarding/PhoneEntrySection.swift`
- `ReMind/Views/Onboarding/CodeEntryScreen.swift`
- `ReMind/Views/Onboarding/CodeEntrySection.swift`
- `ReMind/Views/Onboarding/ConsentAndAgreeBottom.swift`
- `ReMind/ViewModels/AppViewModel/AppViewModel+UserProfile.swift`

Flow:

- User enters a US phone number.
- User agrees to receive text messages from BrainMail.
- Firebase phone auth sends/verifies OTP.
- A Firestore user profile is created or repaired.
- The app loads profile, settings, entries, feature tour state, subscription state, and listeners.

Legal links should currently point to:

- Community Guidelines: `https://brainmailapp.github.io/BrainMail-site/`
- Terms: `https://brainmailapp.github.io/BrainMail-site/terms.html`
- Privacy Policy: `https://brainmailapp.github.io/BrainMail-site/privacy.html`

## Firebase / Firestore Structure

Core collections and documents:

- `users/{uid}`: user profile, phone, SMS operational flags, subscription mirror fields, usage, metrics, last reminder.
- `users/{uid}/entries/{entryId}`: private reminder bank entries.
- `users/{uid}/meta/settings`: reminder frequency, quiet hours, time zone, client revision.
- `users/{uid}/blockedUsers/{blockedUid}`: community block list.
- `communityPosts/{postId}`: public community posts.
- `communityPosts/{postId}/comments/{commentId}`: community thread replies.
- `communityPosts/{postId}/likes/{uid}` and `reports/{uid}`: interaction state.
- `communityPosts/{postId}/comments/{commentId}/likes/{uid}` and `flags/{uid}`: comment interaction state.
- Storage path `users/{uid}/exports/...`: generated PDF exports.

Rules:

- `firestore.rules` lets users read their own profile, but only write a small allowlist of profile fields.
- Billing, entitlement, usage, SMS delivery, and metric fields are server-owned.
- User entries and settings are user-readable/writable.
- Community create/update/delete is server-owned through callables.

## Cloud Functions Responsibilities

Primary exports are listed in `functions/src/index.ts`.

Community:

- Create posts/comments.
- Toggle likes/reports.
- Enforce post length, comment length, daily post limits, and report limits.

User/SMS:

- `sendOneNow`: manual instant SMS.
- `minuteCron`: scheduled automatic SMS delivery.
- `twilioInboundSms` and `twilioStatusCallback`: inbound Twilio webhooks and status handling.
- `triggerWelcome`: welcome message.

Settings:

- `applyUserSettings`: validates and normalizes reminder settings against server capabilities, then reschedules.

RevenueCat:

- `revenueCatWebhook`: applies RevenueCat subscription mirror to Firestore.
- `reconcileRevenueCatEntitlements`: scheduled reconciliation.

Entries:

- `onEntryCreated`: entry-created trigger behavior.

Exports:

- `getExportUploadUrl`: signed upload URL for PDF export.
- `sendExportLink`: validates export, enforces quota if Free, sends link by SMS.

Inactivity:

- `recordAppActivity`
- Auto-pause policy and scheduler behavior for inactive non-paying users.

## Twilio / Scheduling Notes

Scheduling uses randomized intervals derived from reminders per week, quiet hours, and time zone. The backend should be the source of truth for delivery cadence because client clocks and local settings can be stale or manipulated.

Important details:

- `MIN_ENTRIES_FOR_SCHEDULING` is currently 1.
- `pickEntry` prefers older unsent entries, then older sent entries, then optional recent fallbacks, then any sendable entry.
- Sent entries are marked with `sent`, `sentAt`, `deliveredVia`, and `scheduledFor: null`.
- `recordLastReminder` writes the latest delivered reminder to the user doc for the main screen card.
- `receivedCount` increments after manual, automatic, and export SMS paths where appropriate.

## Limits And Quotas

Current expected limits:

- Free reminders per week: 3.
- Pro reminders per week: 14.
- Free instant sends per week: 1.
- Community posts: 5 per user per 24 hours.
- Community post/comment text max: 500 characters.
- Community content expiration: 7 days.
- Free PDF export link sends: monthly quota enforced by `enforceMonthlyLimit`.

Pitfall:

- Pro users must never hit Free usage limits. Server paths should use `resolveServerCapabilities`; client paths should use `AppViewModel.subscriptionCapabilities` and `shouldApplyFreeUsageLimits`.

## Major UI Patterns And Design Principles

BrainMail UI should feel soft, calm, minimal, and emotionally inviting. It should not feel like a settings form or a productivity app unless the surface is truly settings-oriented.

Patterns:

- Soft filled cards with subtle borders.
- Large rounded corners.
- Gentle blue/pastel accents.
- Native sheets for text input.
- Clear primary CTA, lighter secondary actions.
- Dynamic Type support through `.brainMailDynamicTypeRange()` and layout branches.
- Avoid flashy animation, heavy gradients, modal-feeling custom overlays, and cluttered instructional copy.

Community illustration:

- `CommunityTourIllustration` is the shared animated community graphic used by feature tour/community empty/loading states.

New entry composer:

- Compact home card stays concise.
- A temporary visual ghost expands toward the native sheet before the real compose controls appear.
- Input, Cancel, and Save live only inside `NewEntryComposerSheet`.
- Placeholder copy is "What’s something worth remembering?".

## Known Architectural Pitfalls

- Do not treat `active` as paid status. It is SMS operational state.
- Do not gate Pro UI only on stale Firestore if fresh RevenueCat customer info just confirmed Pro.
- Do not let client-side cached Free state keep applying limits after RevenueCat or server profile says Pro.
- Do not write entitlement fields from random client paths. Server/webhook owns the Firestore mirror.
- Do not bypass Cloud Functions for community writes.
- Do not reintroduce custom keyboard offset hacks for the main entry composer.
- Do not make the Free plan UI look like a multi-plan picker; there is only one paid tier.
- Do not use destructive git commands or revert user edits while working in this repo.
- Be careful with strings: product copy has moved from ReMind to BrainMail, but bundle/project names still contain ReMind.

## Key Files Quick Reference

- `ReMind/App/ReMindApp.swift`: app entry and app lifecycle hooks.
- `ReMind/Views/RootView.swift`: auth/onboarding gate and three-page app shell.
- `ReMind/Views/Main/MainView.swift`: main home screen, recent reminder card, sheets, help content.
- `ReMind/Views/Main/Components/EntryComposer.swift`: compact entry card, opening ghost, and native new-entry sheet.
- `ReMind/ViewModels/AppViewModel/AppViewModel.swift`: central app state, subscription capabilities, listeners.
- `ReMind/ViewModels/AppViewModel/AppViewModel+Entries.swift`: entry add/delete/listen logic.
- `ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift`: initial user/profile/settings load.
- `ReMind/Models/UserProfile.swift`: user model and subscription capability model.
- `ReMind/Payment/RevenueCatManager.swift`: RevenueCat SDK wrapper.
- `ReMind/Payment/SubscriptionSheet.swift`: paywall purchase/restore surface.
- `ReMind/Views/Community/CommunityView.swift`: community feed and thread host.
- `ReMind/Views/Community/CommunityComposerSheet.swift`: community post sheet.
- `ReMind/Utils/CommunityAPI.swift`: community Firestore/callable client.
- `ReMind/Views/Sheets/InspirationBankSheet.swift`: curated inspiration add/remove UI.
- `ReMind/Views/RightPanel/RightPanelPlaceholderView.swift`: right-side settings/stats panel.
- `firestore.rules`: Firestore access control.
- `functions/src/index.ts`: top-level Cloud Function exports and community functions.
- `functions/src/config/options.ts`: backend shared helpers, Firebase admin, Twilio secrets, scheduler helpers.
- `functions/src/user/sendOneNow.ts`: manual instant SMS.
- `functions/src/scheduler/minuteCron.ts`: automatic SMS scheduler.
- `functions/src/entitlements/capabilities.ts`: backend subscription capability resolver.
- `functions/src/revenuecat/webhook.ts`: RevenueCat webhook mirror.
- `functions/src/settings/reminders.ts`: backend reminder setting normalization.
- `functions/src/usage/instantSendQuota.ts`: weekly free instant-send quota.
- `functions/src/usageLimits.ts`: generic monthly usage limits.
