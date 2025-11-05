// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+FeatureTour.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
extension AppViewModel {
    // MARK: - Feature tour helpers
    func advanceFeatureTour() async {
        switch featureTourStep {
        case .settings:
            featureTourStep = .export
        case .export:
            featureTourStep = .sendNow
        case .sendNow:
            await completeFeatureTour(markAsSeen: true)
        }
    }

    func skipFeatureTour() async {
        await completeFeatureTour(markAsSeen: true)
    }

    func applyFeatureTourFlag(_ hasSeen: Bool) {
        hasSeenFeatureTour = hasSeen
        if hasSeen {
            showFeatureTour = false
        } else if user != nil && !showFeatureTour {
            featureTourStep = .settings
            showFeatureTour = true
        }
    }

    func completeFeatureTour(markAsSeen: Bool) async {
        showFeatureTour = false
        featureTourStep = .settings

        guard markAsSeen else { return }
        hasSeenFeatureTour = true

        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).setData([
                "hasSeenFeatureTour": true,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("❌ completeFeatureTour error:", error.localizedDescription)
        }
    }
}
