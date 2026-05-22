// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+Functions.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFunctions

extension AppViewModel {
    private var appActivityWriteCooldown: TimeInterval { 5 * 60 }

    func recordAppActivity(reason: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let now = Date()
        if lastAppActivityRecordedUid == uid,
           let lastAppActivityRecordedAt,
           now.timeIntervalSince(lastAppActivityRecordedAt) < appActivityWriteCooldown {
            return
        }

        lastAppActivityRecordedUid = uid
        lastAppActivityRecordedAt = now
        appActivityTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await self.functions.httpsCallable("recordAppActivity").call([
                    "reason": reason
                ])
            } catch {
#if DEBUG
                print("⚠️ recordAppActivity error:", error.localizedDescription)
#endif
            }
        }
    }

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
            let previousReminder = latestReminderForDisplay
            let clientEntitlement: [String: Any] = [
                "state": subscriptionState.rawValue,
                "effectivePlan": effectivePlan.rawValue,
                "isProUser": isProUser,
                "appliesFreeUsageLimits": shouldApplyFreeUsageLimits,
                "source": String(describing: entitlementSource),
                "reason": subscriptionResolutionReason
            ]
            debugLogUsageGate("sendOneNow.request", extra: clientEntitlement)
            let result = try await functions.httpsCallable("sendOneNow").call([
                "clientEntitlement": clientEntitlement
            ])
            print("✅ sendOneNow result:", result.data)
            await refreshLatestSentReminder()

            if latestReminderForDisplay == previousReminder {
                try? await Task.sleep(nanoseconds: 350_000_000)
                await refreshLatestSentReminder()
            }

            await refreshAll()
        } catch let err as NSError {
            // Decode Firebase Functions errors so we can surface the nice cap message
            if err.domain == FunctionsErrorDomain,
               let code = FunctionsErrorCode(rawValue: err.code),
               code == .resourceExhausted,
               let details = err.userInfo[FunctionsErrorDetailsKey] as? String,
               !details.isEmpty {
                // This is the monthly cap error coming from Cloud Functions
                debugLogUsageGate("sendOneNow.limitReached", extra: ["details": details])
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
