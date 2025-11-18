// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+InitialLoad.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
extension AppViewModel {
    // MARK: - Initial load
    func loadUserAndEntries(_ uid: String?) async {
        guard let uid = uid else {
            detachUserListener()
            self.user = nil
            self.entries = []
            self.smsOptOut = false
            self.isGodModeUser = false
            self.hasSeenFeatureTour = false
            self.featureTourStep = .settings
            self.showFeatureTour = false
            self.hasLoadedInitialProfile = true
            return
        }

        hasLoadedInitialProfile = false
        defer { hasLoadedInitialProfile = true }

        
        // One-time fetch so UI has something immediately
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let documentExists = snap.exists

            // Base identity
            let phone = snap.get("phoneE164") as? String ?? ""

            // Optional timestamps
            let createdAtTS = snap.get("createdAt") as? Timestamp
            let updatedAtTS = snap.get("updatedAt") as? Timestamp
            let trialEndsAtTS = snap.get("trialEndsAt") as? Timestamp

            // Active flag (backend gating)
            let active = snap.get("active") as? Bool

            // Build model
            var profile = UserProfile(
                uid: uid,
                phoneE164: phone,
                createdAt: createdAtTS?.dateValue(),
                updatedAt: updatedAtTS?.dateValue(),
                trialEndsAt: trialEndsAtTS?.dateValue(),
                active: active
            )

            self.user = profile

            // Ancillary flags
            self.smsOptOut = snap.get("smsOptOut") as? Bool ?? false
            let hasSeenTour = snap.get("hasSeenFeatureTour") as? Bool ?? false
            applyFeatureTourFlag(hasSeenTour)

            // If trial was never seeded (older users), seed a trial now to avoid nil UI
            if documentExists && profile.trialEndsAt == nil {
                let trialEnd = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
                do {
                    try await db.collection("users").document(uid).setData([
                        "trialEndsAt": Timestamp(date: trialEnd),
                        "active": true
                    ], merge: true)
                    profile.trialEndsAt = trialEnd
                    profile.active = true
                    self.user = profile
                } catch {
                    print("⚠️ failed to backfill trialEndsAt:", error.localizedDescription)
                }
            }
        } catch {
            print("❌ load user error:", error.localizedDescription)
            if self.user == nil { self.user = UserProfile(uid: uid, phoneE164: "") }
            self.smsOptOut = false
            applyFeatureTourFlag(false)
        }

        attachUserListener(uid)
        await refreshAll()
    }

    // MARK: - On-demand fresh read (used on every toolbar tap)
    /// Re-reads users/{uid}.smsOptOut and updates `smsOptOut`.
    /// Returns the fresh value (false if missing or signed out).
    func reloadSmsOptOut() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.smsOptOut = false
            return false
        }
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let fresh = snap.get("smsOptOut") as? Bool ?? false
            self.smsOptOut = fresh
            return fresh
        } catch {
            print("❌ reloadSmsOptOut error:", error.localizedDescription)
            return self.smsOptOut
        }
    }
}
