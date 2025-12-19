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
    @Published private(set) var isEntitled = false

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
                self?.recomputeEntitlement()
            }
            .store(in: &entitlementCancellables)

        $user
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleTrialExpiryTimer()
                self?.recomputeEntitlement()
            }
            .store(in: &entitlementCancellables)
    }

    private func scheduleTrialExpiryTimer() {
        trialExpiryTimer?.invalidate()
        trialExpiryTimer = nil

        guard let trialEndsAt = user?.trialEndsAt else { return }
        let interval = trialEndsAt.timeIntervalSinceNow
        guard interval > 0 else { return }

        trialExpiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.recomputeEntitlement()
            }
        }
    }

    private func recomputeEntitlement() {
        let entitlementActive = revenueCat.entitlementActive
        let onTrial = user?.trialEndsAt.map { Date() < $0 } ?? false
        let newValue = entitlementActive || onTrial

        guard newValue != isEntitled else { return }
        isEntitled = newValue
    }
}
