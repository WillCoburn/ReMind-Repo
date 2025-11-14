// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+Functions.swift
// ============================
import Foundation
import FirebaseFunctions

@MainActor
extension AppViewModel {
    // MARK: - Send One Now (Cloud Function)
    /// Throws if something goes wrong; caller decides how to surface the error.
    func sendOneNow(isOnline: Bool = NetworkMonitor.shared.isConnected) async throws {
        guard isOnline else {
            // Normally guarded in the UI already, but keep a defensive error here.
            throw NSError(
                domain: "ReMindSendOneNow",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "Please reconnect to the internet to use this feature."]
            )
        }

        do {
            let result = try await functions.httpsCallable("sendOneNow").call([:])
            print("✅ sendOneNow result:", result.data)
            await refreshAll()
        } catch let err as NSError {
            // Decode Firebase Functions errors so we can surface the nice cap message
            if err.domain == FunctionsErrorDomain,
               let code = FunctionsErrorCode(rawValue: err.code),
               code == .resourceExhausted,
               let details = err.userInfo[FunctionsErrorDetailsKey] as? String,
               !details.isEmpty {
                // This is the monthly cap error coming from Cloud Functions
                print("❌ sendOneNow limit reached:", details)
                throw NSError(
                    domain: "ReMindSendOneNow",
                    code: err.code,
                    userInfo: [NSLocalizedDescriptionKey: details]
                )
            }

            // Fallback: generic error from callable
            print("❌ sendOneNow error:", err.localizedDescription)
            throw NSError(
                domain: "ReMindSendOneNow",
                code: err.code,
                userInfo: [NSLocalizedDescriptionKey: err.localizedDescription]
            )
        }
    }
}
