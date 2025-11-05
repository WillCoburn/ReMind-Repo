// ============================
// File: App/ViewModels/AppViewModel/AppViewModel.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - User & entries
    @Published var user: UserProfile?
    @Published var entries: [Entry] = []
    @Published var isLoading = false

    // Current SMS opt-out state for the signed-in user
    @Published var smsOptOut: Bool = false

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

    var isOnboarded: Bool { user != nil }

    // MARK: - Init
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { await self.loadUserAndEntries(user?.uid) }
        }
    }
}
