// =============================
// File: App/ViewModels/AppViewModel.swift
// =============================
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

        // If you already set this up elsewhere, it's fine to keep; this is safe to duplicate-check.
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if user == nil {
                // Signed out
                self.profile = nil
                self.affirmations = []
                self.isOnboarded = false
            }
        }
    }

    // MARK: - Logout
    func logout() {
        // 1) Sign out of Firebase
        do { try Auth.auth().signOut() }
        catch { print("❌ Failed to sign out: \(error)") }

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



