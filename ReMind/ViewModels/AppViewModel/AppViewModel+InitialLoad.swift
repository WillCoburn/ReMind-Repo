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
            self.hasSeenFeatureTour = false
            self.featureTourStep = .settings
            self.showFeatureTour = false
            return
        }

        // One-time fetch so UI has something immediately
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let phone = snap.get("phoneE164") as? String ?? ""
            self.user = UserProfile(uid: uid, phoneE164: phone)
            self.smsOptOut = snap.get("smsOptOut") as? Bool ?? false
            let hasSeenTour = snap.get("hasSeenFeatureTour") as? Bool ?? false
            applyFeatureTourFlag(hasSeenTour)
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
