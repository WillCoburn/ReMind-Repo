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
    /// Creates/merges the Firestore user document and seeds baseline freemium fields,
    /// THEN identifies RevenueCat so RC writes happen **after** the base doc exists.
    func setPhoneProfileAndLoad(_ phoneDigits: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required."])
        }
        let e164 = "+1\(phoneDigits)"

        // Seed local model immediately so UI has identity
        let profile = UserProfile(uid: uid, phoneE164: e164)
        self.user = profile

        let shouldFinishSeed = !isSeedingUserProfile
        isSeedingUserProfile = true
        defer {
            if shouldFinishSeed {
                isSeedingUserProfile = false
            }
        }
        
        let docRef = db.collection("users").document(uid)

        let existingSnapshot = try await docRef.getDocument()
        let serverRead = (existingSnapshot.get("updatedAt") as? Timestamp
            ?? existingSnapshot.get("createdAt") as? Timestamp)?.dateValue()
        updateServerTime(readAt: serverRead)

        if existingSnapshot.exists {
            let existingData = existingSnapshot.data() ?? [:]
            let existingCreatedAt = existingData["createdAt"] as? Timestamp
            // Only repair a missing createdAt once; never overwrite a historical timestamp
            var mergePayload: [String: Any] = [
                "uid": uid,
                "phoneE164": e164,
                "updatedAt": FieldValue.serverTimestamp()
            ]

            if existingCreatedAt == nil {
                mergePayload["createdAt"] = FieldValue.serverTimestamp()
            }

            try await docRef.setData(mergePayload, merge: true)

            if let createdAtDate = existingCreatedAt?.dateValue() {
                self.user?.createdAt = createdAtDate
            } else if mergePayload["createdAt"] != nil {
                self.user?.createdAt = Date()
            }
        } else {
            try await docRef.setData([
                "uid": uid,
                "phoneE164": e164,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ], merge: true)
            self.user?.createdAt = Date()
        }


        // Paid-state fields are server-owned. RevenueCat refresh updates local UX
        // while webhooks maintain the Firestore billing mirror.
        RevenueCatManager.shared.recomputeAndPersistActive(uid: uid)
        refreshRevenueCatEntitlement(reason: "setPhoneProfile")

        // Load the rest of app state
        await refreshAll()
    }

    func completeOnboardingAfterSignIn(phoneDigits: String) async throws {
        defer { finishOnboardingAuthTransition() }
        try await setPhoneProfileAndLoad(phoneDigits)

        do {
            _ = try await functions.httpsCallable("triggerWelcome").call([:])
        } catch {
            print("triggerWelcome error:", error.localizedDescription)
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
        detachEntriesListener()
        self.user = nil
        self.entries = []
        self.smsOptOut = false
        self.hasSeenFeatureTour = false
        self.featureTourStep = .settings
        self.showFeatureTour = false
        self.resetSubscriptionStateForAuthChange()
        self.lastAppActivityRecordedAt = nil
        self.lastAppActivityRecordedUid = nil
        RevenueCatManager.shared.clearForLogout()
    }
    // MARK: - Delete account
    func deleteAccount() async throws {
        guard let authUser = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No signed-in user."])
        }

        let uid = authUser.uid

        detachUserListener()
        detachEntriesListener()

        var firstError: Error?
        
        // Remove the user's entries so data is purged alongside the profile.
        do {
            let entriesSnapshot = try await db
                .collection("users")
                .document(uid)
                .collection("entries")
                .getDocuments()

            for document in entriesSnapshot.documents {
                do {
                    try await document.reference.delete()
                } catch {
                    if firstError == nil { firstError = error }
                }
            }
        } catch {
            if firstError == nil { firstError = error }
        }

        // Remove the user document itself.
        // Remove the user document itself (best-effort).
        do {
            let userRef = db.collection("users").document(uid)
            if try await userRef.getDocument().exists {
                try await userRef.delete()
            }
        } catch {
            if firstError == nil { firstError = error }
        }

        // Delete the Firebase Auth user, or at least sign out so the UI can recover.
        do {
            try await authUser.delete()
            try? Auth.auth().signOut()
        } catch {
            if firstError == nil { firstError = error }
            try? Auth.auth().signOut()
        }

        // Clear local state immediately (so onboarding shows without waiting for the listener).
        await loadUserAndEntries(nil)
        if let firstError {
            throw firstError
        }
    }
}
