// App/ViewModels/AppViewModel.swift
import Foundation
import FirebaseAuth

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Published UI state
    @Published var isOnboarded: Bool = false
    @Published var profile: UserProfile?
    @Published var affirmations: [Affirmation] = []
    @Published var submissionsCount: Int = 0

    // MARK: - Dependencies
    private let store: DataStore

    // Auth state listener (optional, used so we can remove it on logout)
    private var authListener: AuthStateDidChangeListenerHandle?

    // MARK: - Init
    init(store: DataStore) {
        self.store = store

        // Keep UI in sync with auth state
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if user == nil {
                // Signed out
                self.profile = nil
                self.affirmations = []
                self.isOnboarded = false
                self.submissionsCount = 0
            } else {
                // Signed in, try to load initial data
                Task { await self.refreshAll() }
            }
        }
    }

    // MARK: - Public API called by Views

    /// After successful phone verification, persist minimal user profile and preload data.
    func setPhoneProfileAndLoad(_ tenDigitUS: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let e164 = "+1\(tenDigitUS)"
        do {
            try await store.createOrUpdateUser(UserProfile(uid: uid, phoneE164: e164))
            await refreshAll()
            isOnboarded = true
        } catch {
            print("❌ setPhoneProfileAndLoad error:", error)
        }
    }

    /// Submit a new affirmation, update UI lists/counters.
    func submit(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let new = try await store.addAffirmation(trimmed)
            // Prepend for top-of-list UX
            affirmations.insert(new, at: 0)
            submissionsCount += 1
        } catch {
            print("❌ submit error:", error)
        }
    }

    /// Reload user + affirmations from the backend.
    func refreshAll() async {
        do {
            // Current user (if any)
            let current = try await store.currentUser()
            self.profile = current

            // List entries
            let list = try await store.listAffirmations()
            self.affirmations = list
            self.submissionsCount = list.count

            // If user exists, consider them onboarded
            self.isOnboarded = (current != nil)
        } catch {
            print("❌ refreshAll error:", error)
        }
    }

    // MARK: - Logout
    func logout() {
        // 1) Sign out of Firebase
        do { try Auth.auth().signOut() } catch {
            print("❌ Failed to sign out: \(error)")
        }
        // 2) Remove auth listener if present
        if let h = authListener {
            Auth.auth().removeStateDidChangeListener(h)
            authListener = nil
        }
        // 3) Clear local UI state so RootView will show onboarding again
        profile = nil
        affirmations = []
        isOnboarded = false
        submissionsCount = 0
    }
}
