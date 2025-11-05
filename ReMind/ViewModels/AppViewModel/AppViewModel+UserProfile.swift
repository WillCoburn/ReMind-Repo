// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+UserProfile.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
extension AppViewModel {
    // MARK: - User Profile
    func setPhoneProfileAndLoad(_ phoneDigits: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let profile = UserProfile(uid: uid, phoneE164: "+1\(phoneDigits)")
        self.user = profile

        do {
            try await db.collection("users").document(uid).setData([
                "uid": profile.uid,
                "phoneE164": profile.phoneE164,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            await refreshAll()
        } catch {
            print("❌ setPhoneProfileAndLoad error:", error.localizedDescription)
        }
    }

    // MARK: - Logout
    func logout() {
        do { try Auth.auth().signOut() } catch {
            print("❌ signOut error:", error.localizedDescription)
        }
        detachUserListener()
        self.user = nil
        self.entries = []
        self.smsOptOut = false
        self.hasSeenFeatureTour = false
        self.featureTourStep = .settings
        self.showFeatureTour = false
    }
}
