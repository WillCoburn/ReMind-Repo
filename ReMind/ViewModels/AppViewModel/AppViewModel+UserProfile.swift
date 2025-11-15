// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+UserProfile.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Mirrors the value stored in users/{uid}.subscriptionStatus
enum SubscriptionStatus: String { case subscribed, unsubscribed }

@MainActor
extension AppViewModel {
    // MARK: - User Profile (create or merge on sign-in)
    /// Creates/merges the Firestore user document and seeds a 30-day trial,
    /// THEN identifies RevenueCat so RC writes happen **after** the base doc exists.
    func setPhoneProfileAndLoad(_ phoneDigits: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let e164 = "+1\(phoneDigits)"

        // Seed local model immediately so UI has identity
        let profile = UserProfile(uid: uid, phoneE164: e164)
        self.user = profile


        do {
            let docRef = db.collection("users").document(uid)

            let existingSnapshot = try await docRef.getDocument()

            if existingSnapshot.exists {
                try await docRef.setData([
                    "uid": uid,
                    "phoneE164": e164,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            } else {
                // Compute trial end locally (server will store canonical timestamps)
                let now = Date()
                let trialEnd = Calendar.current.date(byAdding: .day, value: 30, to: now)
                    ?? now.addingTimeInterval(60 * 60 * 24 * 30)

                try await docRef.setData([
                    "uid": uid,
                    "phoneE164": e164,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                    "trialEndsAt": Timestamp(date: trialEnd),
                    "subscriptionStatus": SubscriptionStatus.unsubscribed.rawValue,
                    "active": true   // starts active during trial
                ], merge: true)
            }

            // ✅ Identify with RevenueCat only AFTER base doc exists.
            RevenueCatManager.shared.identifyIfPossible()

            // Ensure `active` reflects RC entitlement vs. trial (covers re-sign-in edge cases)
            RevenueCatManager.shared.recomputeAndPersistActive(uid: uid)

            // Load the rest of app state
            await refreshAll()
        } catch {
            print("❌ setPhoneProfileAndLoad error:", error.localizedDescription)
        }
    }

    // MARK: - Logout
    func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("❌ signOut error:", error.localizedDescription)
        }

        // Clear in-memory + UI state
        detachUserListener()
        self.user = nil
        self.entries = []
        self.smsOptOut = false
        self.hasSeenFeatureTour = false
        self.featureTourStep = .settings
        self.showFeatureTour = false
    }
}
