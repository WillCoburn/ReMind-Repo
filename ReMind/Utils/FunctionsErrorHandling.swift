// ============================
// File: Shared/FunctionsErrorHandling.swift
// ============================
import Foundation
import FirebaseFunctions

/// Centralized handler for Firebase callable function errors.
/// Shows the special "monthly cap hit" message when the backend
/// returns a `resource-exhausted` error, otherwise falls back
/// to the normal localizedDescription.
struct FunctionsErrorHandler {

    static func handle(
        _ error: Error,
        setAlert: (_ title: String, _ message: String) -> Void
    ) {
        let nsError = error as NSError

        // We only get these for callable functions
        if nsError.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: nsError.code)

            // Our cap helper throws `resource-exhausted` with the custom message
            if code == .resourceExhausted,
               let details = nsError.userInfo[FunctionsErrorDetailsKey] as? String,
               !details.isEmpty {
                setAlert("Re[Mind] Limit Reached", details)
                return
            }
        }

        // Fallback: any other error
        let message = (error as NSError).localizedDescription
        setAlert("Error", message)
    }
}
