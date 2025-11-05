// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+RealtimeUserListener.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
extension AppViewModel {
    // MARK: - Live user doc listener
    func attachUserListener(_ uid: String) {
        userListener?.remove()
        userListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self, let data = snap?.data() else { return }
                let phone = data["phoneE164"] as? String ?? self.user?.phoneE164 ?? ""
                self.user = UserProfile(uid: uid, phoneE164: phone)
                self.smsOptOut = data["smsOptOut"] as? Bool ?? false
                let hasSeenTour = data["hasSeenFeatureTour"] as? Bool ?? false
                self.applyFeatureTourFlag(hasSeenTour)
            }
    }

    func detachUserListener() {
        userListener?.remove()
        userListener = nil
    }
}
