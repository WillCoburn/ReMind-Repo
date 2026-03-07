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
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
                let trialEndsAt = (data["trialEndsAt"] as? Timestamp)?.dateValue()
                let active = data["active"] as? Bool
                let plan = UserPlan(rawValue: ((data["plan"] as? String) ?? "").lowercased())
                let receivedCount = (data["receivedCount"] as? Int)
                    ?? (data["receivedCount"] as? NSNumber)?.intValue
                    ?? self.user?.receivedCount
                let usage = data["usage"] as? [String: Any]
                let instantUsage = InstantUsage(
                    instantWeekKey: usage?["instantWeekKey"] as? String,
                    instantSendsThisWeek: (usage?["instantSendsThisWeek"] as? Int)
                        ?? (usage?["instantSendsThisWeek"] as? NSNumber)?.intValue
                        ?? 0
                )

                // Build updated profile
                let updatedProfile = UserProfile(
                    uid: uid,
                    phoneE164: phone,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    trialEndsAt: trialEndsAt,
                    active: active,
                    plan: plan,
                    receivedCount: receivedCount,
                    usage: instantUsage
                )

                self.user = updatedProfile
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
