// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+GodMode.swift
// ============================
import Foundation
import FirebaseAuth

@MainActor
extension AppViewModel {
    func refreshGodModeFlag(forceRefresh: Bool = false) async {
        guard let authUser = Auth.auth().currentUser else {
            isGodModeUser = false
            return
        }

        do {
            let tokenResult = try await authUser.getIDTokenResult(forcingRefresh: forceRefresh)
            let claim = tokenResult.claims["godMode"]
            let enabled: Bool
            if let boolClaim = claim as? Bool {
                enabled = boolClaim
            } else if let numberClaim = claim as? NSNumber {
                enabled = numberClaim.boolValue
            } else if let stringClaim = claim as? String {
                enabled = (stringClaim as NSString).boolValue
            } else {
                enabled = false
            }
            isGodModeUser = enabled
        } catch {
            print("⚠️ refreshGodModeFlag failed:", error.localizedDescription)
            isGodModeUser = false
        }
    }
}

private extension User {
    func getIDTokenResult(forcingRefresh: Bool) async throws -> AuthTokenResult {
        try await withCheckedThrowingContinuation { continuation in
            self.getIDTokenResult(forcingRefresh: forcingRefresh) { result, error in
                if let result = result {
                    continuation.resume(returning: result)
                } else {
                    let nsError = error ?? NSError(domain: "GodMode", code: -1)
                    continuation.resume(throwing: nsError)
                }
            }
        }
    }
}
