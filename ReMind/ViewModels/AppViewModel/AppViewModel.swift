// ============================
// File: App/ViewModels/AppViewModel/AppViewModel.swift
// ============================
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - User & entries
    @Published var user: UserProfile?
    @Published var entries: [Entry] = []
    @Published var isLoading = false
    @Published var hasLoadedInitialProfile = false
    enum EntitlementSource { case unknown, cached, revenueCat }

    @Published private(set) var isEntitled = false
    @Published private(set) var isTrialActive = false
    @Published private(set) var hasExpiredTrial = false
    @Published private(set) var entitlementResolved = false
    @Published private(set) var entitlementSource: EntitlementSource = .unknown

    // Current SMS opt-out state for the signed-in user
    @Published var smsOptOut: Bool = false

    // Developer override for community interactions
    @Published var isGodModeUser: Bool = false

    // MARK: - Feature tour state
    enum FeatureTourStep: Int, CaseIterable {
        case settings, export, sendNow
        var index: Int { rawValue + 1 }
    }

    @Published var showFeatureTour: Bool = false
    @Published var featureTourStep: FeatureTourStep = .settings
    @Published internal(set) var hasSeenFeatureTour: Bool = false

    // MARK: - Firebase deps
    let db = Firestore.firestore()
    lazy var functions = Functions.functions()

    // Live user listener (keeps smsOptOut in sync while the app runs)
    var userListener: ListenerRegistration?
    
    // Live entries listener (keeps counts in sync while the app runs)
    var entriesListener: ListenerRegistration?

    // Keep a handle so we can remove the auth listener & avoid warnings.
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var entitlementCancellables: Set<AnyCancellable> = []
    private var trialExpiryTimer: Timer?
    private var lastServerNow: Date?
    private var uptimeAtLastServerNow: TimeInterval?
    private var lastEntitlementActive = false

    let revenueCat: RevenueCatManager = .shared

    /// Legacy convenience; true when a profile is loaded.
    var isOnboarded: Bool { user != nil }

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
            guard let self = self else { return }
            Task {
                // Load user profile and entries for this auth state.
                await self.loadUserAndEntries(authUser?.uid)
                await self.refreshGodModeFlag(forceRefresh: true)

            }
        }

        observeEntitlementSources()
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func observeEntitlementSources() {
        revenueCat.$entitlementActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyEntitlementState(
                    entitlementActive: self.revenueCat.entitlementActive,
                    source: .revenueCat
                )
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

        guard let trialEndsAt = user?.trialEndsAt, let now = trustedNow() else { return }
        let interval = trialEndsAt.timeIntervalSince(now)
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
            entitlementResolved = false
            entitlementSource = .unknown
            lastEntitlementActive = false
            isEntitled = false
            isTrialActive = false
            hasExpiredTrial = false
            return
        }

        if let active = profile.active {
            applyEntitlementState(entitlementActive: active, source: .cached)
        } else {
            refreshEntitlementState()
        }
    }

    private func applyEntitlementState(entitlementActive: Bool, source: EntitlementSource) {
        let resolvedSource: EntitlementSource
        let resolvedActive: Bool

        if entitlementSource == .revenueCat && source == .cached {
            resolvedSource = entitlementSource
            resolvedActive = lastEntitlementActive
        } else {
            resolvedSource = source
            resolvedActive = entitlementActive
        }

        let onTrial = computeTrialActive()
        let newValue = resolvedActive || onTrial
        let expiredTrial = (!resolvedActive && !onTrial && user?.trialEndsAt != nil)

        guard newValue != isEntitled
                || onTrial != isTrialActive
                || expiredTrial != hasExpiredTrial
                || !entitlementResolved
                || entitlementSource != resolvedSource
                || lastEntitlementActive != resolvedActive else { return }

        isEntitled = newValue
        isTrialActive = onTrial
        hasExpiredTrial = expiredTrial
        entitlementResolved = true
        entitlementSource = resolvedSource
        lastEntitlementActive = resolvedActive
    }

    private func computeTrialActive() -> Bool {
        guard let trialEndsAt = user?.trialEndsAt else { return false }
        guard let now = trustedNow() else { return false }
        return now < trialEndsAt
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
        guard entitlementSource != .unknown else { return }
        applyEntitlementState(entitlementActive: lastEntitlementActive, source: entitlementSource)
        scheduleTrialExpiryTimer()
    }

    func refreshRevenueCatEntitlement() {
        revenueCat.forceIdentify { [weak self] in
            self?.revenueCat.refreshEntitlementState()
        }
    }
}
