// ============================
// File: App/ViewModels/AppViewModel/AppViewModel.swift
// ============================
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import RevenueCat

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - User & entries
    @Published var user: UserProfile?
    @Published var entries: [Entry] = []
    @Published private(set) var latestSentReminder: LastReminder?
    @Published var isLoading = false
    @Published var hasLoadedInitialProfile = false
    enum EntitlementSource { case unknown, cached, revenueCat, error }

    @Published private(set) var isEntitled = false
    @Published var isSubscribed = false
    @Published private(set) var isTrialActive = false
    @Published private(set) var hasExpiredTrial = false
    @Published private(set) var entitlementResolved = false
    @Published private(set) var entitlementSource: EntitlementSource = .unknown
    @Published private(set) var subscriptionState: SubscriptionState = .loading
    @Published private(set) var lastKnownSubscriptionWasPro = false
    @Published private(set) var subscriptionResolutionReason: String = "initial"
    
    /// True once Firebase auth state + user profile have been resolved at least once
    var isAuthInitialized: Bool {
        hasLoadedInitialProfile
    }


    // Current SMS opt-out state for the signed-in user
    @Published var smsOptOut: Bool = false

    // Developer override for community interactions
    @Published var isGodModeUser: Bool = false

    // MARK: - Feature tour state
    enum FeatureTourStep: Int, CaseIterable {
        case settings, export, reminders, sendNow, phoneNumber
        var index: Int { rawValue + 1 }
    }

    @Published var showFeatureTour: Bool = false
    @Published var featureTourStep: FeatureTourStep = .settings
    @Published var hasSeenFeatureTour: Bool = false

    // MARK: - Firebase deps
    let db = Firestore.firestore()
    lazy var functions = Functions.functions()

    // Live user listener (keeps smsOptOut in sync while the app runs)
    var userListener: ListenerRegistration?
    
    // Live entries listener (keeps counts in sync while the app runs)
    var entriesListener: ListenerRegistration?

    // Keep a handle so we can remove the auth listener & avoid warnings.
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var authLoadTask: Task<Void, Never>?
    private var entitlementCancellables: Set<AnyCancellable> = []
    private var trialExpiryTimer: Timer?
    private var lastServerNow: Date?
    private var uptimeAtLastServerNow: TimeInterval?
    private var lastEntitlementActive = false
    private var freshRevenueCatProOverride: FreshRevenueCatProOverride?
    private let freshRevenueCatProOverrideTTL: TimeInterval = 30 * 60
    var isSeedingUserProfile = false
    var lastAppActivityRecordedAt: Date?
    var lastAppActivityRecordedUid: String?
    var appActivityTask: Task<Void, Never>?

    let revenueCat: RevenueCatManager = .shared

    private struct FreshRevenueCatProOverride {
        let appUserID: String?
        let receivedAt: Date
        let expiresAt: Date?
    }

    /// Legacy convenience; true when a profile is loaded.
    var isOnboarded: Bool { user != nil }

    /// New source-of-truth tier signal.
    /// Defaults to `.free` when missing for backward compatibility.
    var effectivePlan: UserPlan {
        subscriptionCapabilities.effectivePlan
    }

    var isProUser: Bool {
        subscriptionCapabilities.isProUser
    }

    var subscriptionCapabilities: SubscriptionCapabilities {
        SubscriptionCapabilities.resolve(
            state: subscriptionState,
            lastKnownSubscribed: lastKnownSubscriptionWasPro
        )
    }

    var shouldUseProReminderRange: Bool {
        subscriptionCapabilities.canUseProReminderRange
    }

    var shouldShowUpgradeMessaging: Bool {
        subscriptionCapabilities.shouldShowUpgradeMessaging
    }

    var shouldApplyFreeUsageLimits: Bool {
        subscriptionCapabilities.shouldApplyFreeUsageLimits
    }

    var isSubscriptionLoading: Bool {
        subscriptionState == .loading
    }

    var maxRemindersPerWeekForCurrentSubscription: Double {
        subscriptionCapabilities.maxRemindersPerWeek
    }

    var hasUsedFreeInstantSendThisWeek: Bool {
        guard shouldApplyFreeUsageLimits else { return false }
        guard let usage = user?.usage else { return false }
        let tzIdentifier = UserDefaults.standard.string(forKey: "tzIdentifier") ?? TimeZone.current.identifier
        let weekKey = Self.instantWeekKey(now: Date(), tzIdentifier: tzIdentifier)
        let sends = usage.instantWeekKey == weekKey ? usage.instantSendsThisWeek : 0
        let limitReached = sends >= 1
        if limitReached {
            debugLogUsageGate(
                "clientFreeInstantLimit",
                extra: [
                    "weekKey": weekKey,
                    "instantSendsThisWeek": sends,
                    "usageWeekKey": usage.instantWeekKey ?? "nil"
                ]
            )
        }
        return limitReached
    }

    var latestReminderForDisplay: LastReminder? {
        let sentEntryReminders = entries.compactMap { entry -> LastReminder? in
            guard entry.sent else { return nil }
            return LastReminder(
                text: entry.text,
                sentAt: entry.sentAt ?? entry.createdAt,
                entryId: entry.id,
                deliveredVia: nil
            )
        }

        return ([latestSentReminder].compactMap { $0 } + sentEntryReminders)
            .max { lhs, rhs in
                (lhs.sentAt ?? .distantPast) < (rhs.sentAt ?? .distantPast)
            }
    }

    static func instantWeekKey(now: Date, tzIdentifier: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = TimeZone(identifier: tzIdentifier) ?? .current
        let weekday = calendar.component(.weekday, from: now)
        let offset = weekday == 1 ? -6 : 2 - weekday
        guard let monday = calendar.date(byAdding: .day, value: offset, to: now) else {
            return "1970-01-01"
        }
        let comps = calendar.dateComponents([.year, .month, .day], from: monday)
        let y = comps.year ?? 1970
        let m = String(format: "%02d", comps.month ?? 1)
        let d = String(format: "%02d", comps.day ?? 1)
        return "\(y)-\(m)-\(d)"
    }

    /// Onboarding gate:
    /// - Show onboarding if there is NO Firebase session
    /// - Or if we don’t yet have a phone number in the loaded profile
    var shouldShowOnboarding: Bool {
        if !hasLoadedInitialProfile { return false }
        // If Firebase has no user, we must show onboarding.
        guard Auth.auth().currentUser != nil else { return true }

        // Firebase has a session. Require a loaded profile with a phone number.
        let hasPhone = !(user?.phoneE164 ?? "").isEmpty
        return !hasPhone
    }

    // MARK: - Init / Deinit
    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, authUser in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.authLoadTask?.cancel()
                self.authLoadTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.resetSubscriptionStateForAuthChange()
                    await self.waitForProfileSeedIfNeeded()
                    guard !Task.isCancelled else { return }
                    // Load user profile and entries for this auth state.
                    await self.loadUserAndEntries(authUser?.uid)
                    guard !Task.isCancelled else { return }
                    await self.refreshGodModeFlag(forceRefresh: true)
                }
            }
        }

        observeEntitlementSources()
    }

    deinit {
        authLoadTask?.cancel()
        appActivityTask?.cancel()
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func observeEntitlementSources() {
        revenueCat.$lastCustomerInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                guard let self else { return }
                guard let info else {
                    self.refreshEntitlementState()
                    return
                }
                self.applyFreshRevenueCatCustomerInfo(info, reason: "revenueCatCustomerInfo")
            }
            .store(in: &entitlementCancellables)
        revenueCat.$lastRefreshError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error else { return }
                self.subscriptionResolutionReason = "revenueCatError:\(error)"
                self.refreshEntitlementState()
            }
            .store(in: &entitlementCancellables)
        
        $user
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.handleUserProfileChange(profile)
            }
            .store(in: &entitlementCancellables)
    }

    private func scheduleTrialExpiryTimer() {
        trialExpiryTimer?.invalidate()
        trialExpiryTimer = nil

        guard let trialEndsAt = user?.trialEndsAt else { return }
        let interval = trialEndsAt.timeIntervalSince(referenceNow())
        guard interval > 0 else { return }

        trialExpiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshEntitlementState()
            }
        }
    }

    private func handleUserProfileChange(_ profile: UserProfile?) {
        scheduleTrialExpiryTimer()

        guard let profile else {
            subscriptionState = .loading
            subscriptionResolutionReason = "signedOut"
            entitlementResolved = false
            entitlementSource = .unknown
            lastEntitlementActive = false
            lastKnownSubscriptionWasPro = false
            freshRevenueCatProOverride = nil
            isEntitled = false
            isSubscribed = false
            isTrialActive = false
            hasExpiredTrial = false
            return
        }

        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: profile.plan,
            subscriptionStatus: profile.subscriptionStatus,
            profileLoaded: true,
            lastKnownSubscribed: lastKnownSubscriptionWasPro,
            rcEntitlementActive: profile.rcEntitlementActive,
            rcExpiresAt: profile.rcExpiresAt,
            referenceDate: referenceNow()
        )
        applyResolvedSubscriptionState(capabilities, source: .cached, reason: "serverProfile")
    }

    func applyEntitlementState(entitlementActive: Bool, source: EntitlementSource) {
        let state: SubscriptionState = entitlementActive ? .subscribed : .free
        applySubscriptionState(state, source: source, reason: entitlementActive ? "legacyActive" : "legacyInactive")
    }

    private func applySubscriptionState(
        _ state: SubscriptionState,
        source: EntitlementSource,
        reason: String
    ) {
        let onTrial = computeTrialActive()
        let expiredTrial = (state == .expired) || (state != .subscribed && !onTrial && user?.trialEndsAt != nil)
        let entitled = state == .subscribed
        let resolved = state.isResolved

        if state == .subscribed {
            lastKnownSubscriptionWasPro = true
        } else if state == .free || state == .expired {
            lastKnownSubscriptionWasPro = false
        }

        guard state != subscriptionState
                || entitled != isEntitled
                || (state == .subscribed) != isSubscribed
                || onTrial != isTrialActive
                || expiredTrial != hasExpiredTrial
                || resolved != entitlementResolved
                || entitlementSource != source
                || lastEntitlementActive != (state == .subscribed)
                || subscriptionResolutionReason != reason else { return }

        subscriptionState = state
        subscriptionResolutionReason = reason
        isEntitled = entitled
        isSubscribed = state == .subscribed
        isTrialActive = onTrial
        hasExpiredTrial = expiredTrial
        entitlementResolved = resolved
        entitlementSource = source
        lastEntitlementActive = state == .subscribed
        logSubscriptionResolution(reason: reason)
    }

    private func computeTrialActive() -> Bool {
        guard let trialEndsAt = user?.trialEndsAt else { return false }
        return referenceNow() < trialEndsAt
    }

    private func referenceNow() -> Date {
        trustedNow() ?? Date()
    }

    private func trustedNow() -> Date? {
        guard let serverNow = lastServerNow, let uptime = uptimeAtLastServerNow else { return nil }
        let elapsed = ProcessInfo.processInfo.systemUptime - uptime
        return serverNow.addingTimeInterval(elapsed)
    }

    func updateServerTime(readAt: Date?) {
        guard let readAt else { return }
        lastServerNow = readAt
        uptimeAtLastServerNow = ProcessInfo.processInfo.systemUptime
        refreshEntitlementState()
    }

    func refreshEntitlementState() {
        guard let user else {
            guard entitlementSource != .unknown else { return }
            applySubscriptionState(.loading, source: entitlementSource, reason: "refreshWithoutProfile")
            return
        }

        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: user.plan,
            subscriptionStatus: user.subscriptionStatus,
            profileLoaded: true,
            lastKnownSubscribed: lastKnownSubscriptionWasPro,
            rcEntitlementActive: user.rcEntitlementActive,
            rcExpiresAt: user.rcExpiresAt,
            referenceDate: referenceNow()
        )
        applyResolvedSubscriptionState(capabilities, source: .cached, reason: "refreshServerProfile")
        scheduleTrialExpiryTimer()
    }

    func refreshRevenueCatEntitlement(reason: String = "app") {
        revenueCat.forceIdentify(reason: reason) { [weak self] in
            self?.revenueCat.refreshEntitlementState(reason: reason)
        }
    }

    func applyFreshRevenueCatCustomerInfo(_ info: CustomerInfo, reason: String) {
        guard revenueCat.hasActiveProEntitlement(info) else {
            freshRevenueCatProOverride = nil
            refreshEntitlementState()
            return
        }

        let entitlement = info.entitlements[PaywallConfig.entitlementId]
        freshRevenueCatProOverride = FreshRevenueCatProOverride(
            appUserID: Auth.auth().currentUser?.uid,
            receivedAt: referenceNow(),
            expiresAt: entitlement?.expirationDate
        )
        applySubscriptionState(.subscribed, source: .revenueCat, reason: reason)
    }

    func resetSubscriptionStateForAuthChange() {
        subscriptionState = .loading
        subscriptionResolutionReason = "authChange"
        entitlementResolved = false
        entitlementSource = .unknown
        lastEntitlementActive = false
        lastKnownSubscriptionWasPro = false
        freshRevenueCatProOverride = nil
        isEntitled = false
        isSubscribed = false
        isTrialActive = false
        hasExpiredTrial = false
    }

    func beginOnboardingAuthTransition() {
        isSeedingUserProfile = true
        hasLoadedInitialProfile = false
        resetSubscriptionStateForAuthChange()
    }

    func finishOnboardingAuthTransition() {
        isSeedingUserProfile = false
    }

    private func logSubscriptionResolution(reason: String) {
#if DEBUG
        print(
            "🔐 [Subscription][AppVM] state=\(subscriptionState.rawValue) isPro=\(isProUser) lastKnownPro=\(lastKnownSubscriptionWasPro) source=\(entitlementSource) reason=\(reason)"
        )
#endif
    }

    func debugLogUsageGate(_ event: String, extra: [String: Any] = [:]) {
#if DEBUG
        var payload: [String: Any] = [
            "state": subscriptionState.rawValue,
            "effectivePlan": effectivePlan.rawValue,
            "isPro": isProUser,
            "appliesFreeUsageLimits": shouldApplyFreeUsageLimits,
            "entitlementSource": String(describing: entitlementSource),
            "resolutionReason": subscriptionResolutionReason,
            "serverPlan": user?.plan?.rawValue ?? "nil",
            "subscriptionStatus": user?.subscriptionStatus ?? "nil",
            "rcEntitlementActive": user?.rcEntitlementActive.map(String.init) ?? "nil",
            "rcExpiresAt": user?.rcExpiresAt?.description ?? "nil"
        ]
        extra.forEach { payload[$0.key] = $0.value }
        print("🔐 [Subscription][UsageGate] \(event) \(payload)")
#endif
    }

    private func applyResolvedSubscriptionState(
        _ capabilities: SubscriptionCapabilities,
        source: EntitlementSource,
        reason: String
    ) {
        if capabilities.state == .subscribed {
            freshRevenueCatProOverride = nil
            applySubscriptionState(capabilities.state, source: source, reason: reason)
            return
        }

        if hasUsableFreshRevenueCatProOverride() {
            applySubscriptionState(.subscribed, source: .revenueCat, reason: "freshRevenueCatPro:\(reason)")
            return
        }

        applySubscriptionState(capabilities.state, source: source, reason: reason)
    }

    private func hasUsableFreshRevenueCatProOverride() -> Bool {
        guard let override = freshRevenueCatProOverride else { return false }

        if let overrideUserID = override.appUserID,
           let currentUserID = Auth.auth().currentUser?.uid,
           overrideUserID != currentUserID {
            freshRevenueCatProOverride = nil
            return false
        }

        let now = referenceNow()
        guard now.timeIntervalSince(override.receivedAt) <= freshRevenueCatProOverrideTTL else {
            freshRevenueCatProOverride = nil
            return false
        }

        if let expiresAt = override.expiresAt, expiresAt <= now {
            freshRevenueCatProOverride = nil
            return false
        }

        return true
    }

    func parseLastReminder(from data: [String: Any]) -> LastReminder? {
        let raw = data["lastReminder"] as? [String: Any]
        let text = ((raw?["text"] as? String) ?? (data["lastReminderText"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let nestedSentAt = (raw?["sentAt"] as? Timestamp)?.dateValue()
        let flatSentAt = (data["lastReminderSentAt"] as? Timestamp)?.dateValue()

        return LastReminder(
            text: text,
            sentAt: nestedSentAt ?? flatSentAt,
            entryId: (raw?["entryId"] as? String) ?? (data["lastReminderEntryId"] as? String),
            deliveredVia: raw?["deliveredVia"] as? String
        )
    }

    func parseFirestoreDate(_ raw: Any?) -> Date? {
        if let timestamp = raw as? Timestamp { return timestamp.dateValue() }
        if let date = raw as? Date { return date }
        if let number = raw as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        if let seconds = raw as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let string = raw as? String, let seconds = TimeInterval(string) {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }

    func applyLatestSentReminder(_ reminder: LastReminder?) {
        latestSentReminder = reminder
    }

    private func waitForProfileSeedIfNeeded() async {
        guard isSeedingUserProfile else { return }
        let maxAttempts = 20
        for _ in 0..<maxAttempts {
            if !isSeedingUserProfile { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
