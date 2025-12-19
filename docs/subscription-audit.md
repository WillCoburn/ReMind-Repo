# Subscription Enforcement & Trial Audit

## 1. State sources and consistency
- **RevenueCat (RC):** `RevenueCatManager` publishes entitlement flags (`entitlementActive`, `entitlementWillRenew`, `entitlementExpirationDate`) and keeps the latest `CustomerInfo` plus the management URL.【F:ReMind/Payment/RevenueCatManager.swift†L16-L85】 These values are set when RC callbacks run but views do not observe the manager, so SwiftUI renders are not triggered by RC changes.
- **Firestore user doc:** The app reads `trialEndsAt`, `active`, and `subscriptionStatus` once during `loadUserAndEntries`; missing trials are backfilled locally as active for 30 days.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L30-L92】 The onboarding path also seeds `trialEndsAt`, `active`, and `subscriptionStatus` when creating/repairing a profile.【F:ReMind/ViewModels/AppViewModel/AppViewModel+UserProfile.swift†L14-L96】
- **Firestore RC mirror:** RC snapshots are written into `users/{uid}.rc` and then used to recompute `active`/`subscriptionStatus` plus schedule a local trial-expiry timer.【F:ReMind/Payment/RevenueCatManager.swift†L87-L246】
- **Local timers:** `RevenueCatManager` schedules a `Timer` for trial expiry to trigger `recomputeAndPersistActive`, but the UI never listens to the resulting Firestore writes.【F:ReMind/Payment/RevenueCatManager.swift†L224-L246】【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L87-L90】
- **Authoritative state at runtime:** UI gating relies on `isActive(trialEndsAt:activeFlag:)`, which combines RC entitlement, locally cached trial end, and the cached Firestore `active` flag from the initial fetch.【F:ReMind/Views/Main/MainView.swift†L30-L48】【F:ReMind/Views/Community/CommunityView.swift†L22-L35】 Because there is no live user listener and RC changes aren’t observed, whichever snapshot was present at last fetch effectively becomes authoritative, even if RC or Firestore change later.
- **Staleness/conflicts:**
  - RC entitlement updates (purchase/cancel/restore) do not automatically refresh `appVM.user` or trigger view updates, so gating can remain in the old state indefinitely.
  - Firestore `active` recomputations happen asynchronously but views never re-read the document after the initial load (listeners are commented out), so RC and Firestore can diverge from UI state.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L30-L92】
  - Trial-expiry timer writes to Firestore but the UI keeps using the cached `active`/`trialEndsAt`, allowing interaction after expiry until a manual reload.

## 2. Trial lifecycle edge cases
- **Trial just started:** Onboarding seeds `active=true` and a future `trialEndsAt`, so gating allows all actions even if RC is not configured yet.【F:ReMind/ViewModels/AppViewModel/AppViewModel+UserProfile.swift†L48-L95】【F:ReMind/Views/Main/MainView.swift†L30-L48】
- **Trial ends in foreground/background:** Timer recomputes Firestore state at expiry, but Main/Community views keep using cached `active`/`trialEndsAt` and do not observe RC, so interaction can remain enabled past expiry until another state change triggers a reload.【F:ReMind/Payment/RevenueCatManager.swift†L224-L246】【F:ReMind/Views/Main/MainView.swift†L30-L112】
- **App terminated/resumed after expiry:** On next launch, the one-time user fetch will load expired `trialEndsAt` and set `hasExpiredTrialWithoutSubscription` to show the banner and disable actions; however, if Firestore still has `active=true` from a missed recompute, gating will stay open.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L30-L92】【F:ReMind/Views/Main/MainView.swift†L37-L114】
- **Open after expiry before RC refresh:** UI uses cached trial/active and ignores pending RC updates, so actions may be allowed until a manual refresh occurs.【F:ReMind/Views/Main/MainView.swift†L30-L114】
- **Reinstall or device switch mid-trial:** Profiles are recreated with the stored `trialEndsAt`/`active`; no RC check runs unless forced, so gating depends on Firestore’s snapshot accuracy.【F:ReMind/ViewModels/AppViewModel/AppViewModel+UserProfile.swift†L45-L96】【F:ReMind/App/ReMindApp.swift†L22-L36】
- **Device clock skew:** `isActive` compares `Date()` to the stored trial end locally, so incorrect device time can misclassify users regardless of server state.【F:ReMind/Views/Main/MainView.swift†L30-L48】
- **Trial expiration offline:** Timer won’t fire without the app running; when offline, trial checks are still local date comparisons, so gating may allow usage past expiry until a refresh happens.【F:ReMind/Payment/RevenueCatManager.swift†L224-L246】【F:ReMind/Views/Main/MainView.swift†L30-L48】

For each case: users can often keep interacting because gating is based on cached values; only the expired-trial banner shows when the cached `trialEndsAt` has passed and `active` is false, otherwise actions remain enabled.【F:ReMind/Views/Main/MainView.swift†L37-L114】 State eventually corrects only after a manual reload that refetches Firestore and/or RC.

## 3. Subscription purchase & restore paths
- **First-time purchase / post-expiry purchase:** Paywall completion calls `refreshEntitlementState` which updates RC state and writes to Firestore, but views do not observe RC and do not re-fetch the user document, so gating may stay locked until app restart.【F:ReMind/Payment/SubscriptionSheet.swift†L8-L18】【F:ReMind/Payment/RevenueCatManager.swift†L56-L133】
- **Restore after reinstall/offline/with errors:** `restore` only updates local RC state (no Firestore writes) and signals completion; without observing RC, UI will not change. Errors simply surface a string without fallback gating updates.【F:ReMind/Payment/RevenueCatManager.swift†L249-L276】【F:ReMind/Views/Settings/Sections/SubscriptionSection.swift†L13-L83】
- **No Firestore dependency guaranteed:** The design assumes Firestore recompute for correctness, but UI gating never consumes the recomputed flags, so purchases/restores can require restarting to lift gating.

## 4. App lifecycle & timing races
- Scene activation triggers `recomputeAndPersistActive`, but the result is never applied to in-memory `user`, so UI may briefly show stale entitlement or stay locked permanently.【F:ReMind/App/ReMindApp.swift†L22-L36】【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L30-L92】
- RevenueCat delegate callbacks update `@Published` values, yet Main/Community do not observe them, so multiple callbacks do not refresh UI gating.【F:ReMind/Payment/RevenueCatManager.swift†L16-L85】【F:ReMind/Views/Main/MainView.swift†L30-L114】
- Firestore reads resolve asynchronously, but without listeners the initial snapshot governs all decisions; timers or RC refreshes that write later are ignored by UI, letting expired users interact until a full reload occurs.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L30-L92】【F:ReMind/Payment/RevenueCatManager.swift†L137-L223】

## 5. UI enforcement coverage
- **Main composer & actions:** Entry composer disabled when `isActive` is false or network missing; Export/Send Now show subscribe alerts if inactive.【F:ReMind/Views/Main/MainView.swift†L30-L355】
- **Community:** Entire feed is blurred/blocked and the compose button shows a subscribe alert when inactive.【F:ReMind/Views/Community/CommunityView.swift†L22-L190】
- **Other paths:** Right settings panel only shows a trial banner and paywall button; it does not gate settings themselves.【F:ReMind/Views/RightPanel/RightPanelPlaceholderView.swift†L300-L335】 No deep-link guards beyond these views are present. Because gating relies on cached state and disabled buttons, navigation could re-enable actions if the cached `active` remains true.

## 6. Error & offline handling
- RevenueCat refresh errors are only logged; UI does not move to a conservative locked state when RC is unavailable.【F:ReMind/Payment/RevenueCatManager.swift†L56-L133】
- Firestore errors during recompute or initial load are logged without updating gating flags, leaving whatever cached state exists in place.【F:ReMind/Payment/RevenueCatManager.swift†L137-L223】【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L30-L92】
- Network loss blocks entry submission/export/send-now via `NetworkMonitor`, but subscription status is not revalidated when connectivity returns.【F:ReMind/Views/Main/MainView.swift†L45-L355】 RC cached data is accepted without distinguishing freshness, so offline launches can keep prior entitlements indefinitely.

## 7. Final verdict
- **Confirmed safe behaviors:**
  - Export/Send Now/Community compose paths all check `isActive` and surface subscribe messaging when that flag is false.【F:ReMind/Views/Main/MainView.swift†L294-L329】【F:ReMind/Views/Community/CommunityView.swift†L22-L69】
  - Trial seeding ensures brand-new users are not blocked on day one.【F:ReMind/ViewModels/AppViewModel/AppViewModel+UserProfile.swift†L45-L96】
- **Potential bugs/risks:**
  - RC entitlement changes are not observed by UI, so purchases, cancellations, or restores do not immediately change gating.【F:ReMind/Payment/RevenueCatManager.swift†L16-L85】【F:ReMind/Views/Main/MainView.swift†L30-L114】
  - Firestore recomputes and trial-expiry timers update backend flags, but views never reload the user doc after the initial fetch, leaving stale `active` values indefinitely.【F:ReMind/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift†L30-L92】【F:ReMind/Payment/RevenueCatManager.swift†L137-L223】
  - Local `Date()` checks allow clock-skew exploits to keep trials active.【F:ReMind/Views/Main/MainView.swift†L30-L48】
  - Settings/right-panel surfaces are not gated, so users can tweak reminder settings while unsubscribed.【F:ReMind/Views/RightPanel/RightPanelPlaceholderView.swift†L300-L335】
- **Recommended fixes:**
  - Observe `RevenueCatManager` in gating views (`@ObservedObject`) and source active state from `lastCustomerInfo` with a single derived `isEntitled` helper.
  - Re-enable the real-time user listener or explicitly refresh the user document whenever RC callbacks or timers run so `appVM.user.active` stays current.
  - Centralize gating in a shared model (e.g., `SubscriptionState`) derived from RC + server timestamps, falling back to locked when data is stale or RC fails.
  - Replace local `Date()` trial checks with server timestamps and avoid trusting device clocks; treat missing/old data as inactive until refreshed.

**Overall:** Subscription enforcement is **unsafe**. UI depends on cached trial/active flags and does not react to live RevenueCat or Firestore updates, so both over-access (expired users allowed) and under-access (paid users still blocked) are likely until the app is restarted or manually refreshed.
