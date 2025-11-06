// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+Functions.swift
// ============================
import Foundation
import FirebaseFunctions

@MainActor
extension AppViewModel {
    // MARK: - Send One Now (Cloud Function)
    /// Returns false immediately if offline.
    func sendOneNow(isOnline: Bool = NetworkMonitor.shared.isConnected) async -> Bool {
        guard isOnline else {
            print("⏸️ sendOneNow skipped: offline")
            return false
        }

        do {
            let result = try await functions.httpsCallable("sendOneNow").call([:])
            print("✅ sendOneNow result:", result.data)
            await refreshAll()
            return true
        } catch {
            print("❌ sendOneNow error:", error.localizedDescription)
            return false
        }
    }
}
