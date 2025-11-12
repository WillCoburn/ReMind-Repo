// ==================================
// File: Services/UserSettingsSync.swift
// ==================================
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

struct UserSettings: Codable {
    var remindersPerDay: Double
    var tzIdentifier: String
    var quietStartHour: Int    // 0...23
    var quietEndHour: Int      // 0...23
}

enum UserSettingsSync {
    static func currentFromAppStorage() -> UserSettings {
        let d = UserDefaults.standard
        return .init(
            remindersPerDay: max(0.1, min(5.0, d.object(forKey: "remindersPerDay") as? Double ?? 1.0)),
            tzIdentifier: d.string(forKey: "tzIdentifier") ?? TimeZone.current.identifier,
            quietStartHour: max(0, min(23, Int(round(d.double(forKey: "quietStartHour"))))),
            quietEndHour:  max(0, min(23, Int(round(d.double(forKey: "quietEndHour")))))
        )
    }

    /// Writes settings to Firestore at users/{uid}/meta/settings
    /// THEN calls the callable `applyUserSettings` to compute users/{uid}.nextSendAt immediately.
    ///
    /// CHANGE: We only write `users/{uid}.active = true` if the user is SUBSCRIBED
    /// or still WITHIN TRIAL. Otherwise we leave `active` untouched, preventing
    /// an unintended reactivation for expired/unsubscribed users.
    static func pushAndApply(completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "UserSettingsSync",
                                code: 401,
                                userInfo: [NSLocalizedDescriptionKey: "Not logged in"]))
            return
        }

        let db = Firestore.firestore()
        let functions = Functions.functions()
        let s = currentFromAppStorage()

        // Prepare settings payload
        let settingsData: [String: Any] = [
            "remindersPerDay": s.remindersPerDay,
            "tzIdentifier": s.tzIdentifier,
            "quietStartHour": s.quietStartHour,
            "quietEndHour": s.quietEndHour,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let userRef = db.collection("users").document(uid)
        let settingsRef = userRef.collection("meta").document("settings")

        // Step 0: Read user to decide if we are allowed to flip `active` to true.
        userRef.getDocument { snapshot, readErr in
            if let readErr = readErr {
                // If we can't read, fail CLOSED (do not accidentally reactivate).
                // We still save settings and call the backend, but we won't write active=true.
                print("⚠️ UserSettingsSync: failed to read user doc; will not force active=true. \(readErr.localizedDescription)")
                commitBatch(shouldSetActiveTrue: false)
                return
            }

            // Parse subscription status & trial window
            var shouldSetActiveTrue = false
            if let doc = snapshot, doc.exists {
                let status = (doc.get("subscriptionStatus") as? String) ?? SubscriptionStatus.unsubscribed.rawValue
                let isSubscribed = (status == SubscriptionStatus.subscribed.rawValue)

                let trialEndsAt: Date? = {
                    if let ts = doc.get("trialEndsAt") as? Timestamp { return ts.dateValue() }
                    return nil
                }()

                let now = Date()
                let withinTrial = (trialEndsAt != nil) ? (now < trialEndsAt!) : false

                shouldSetActiveTrue = isSubscribed || withinTrial
            } else {
                // No user doc? Fail CLOSED: don't re-activate.
                shouldSetActiveTrue = false
            }

            commitBatch(shouldSetActiveTrue: shouldSetActiveTrue)
        }

        // Commits the batch (settings always saved; active=true only when allowed), then calls the callable.
        func commitBatch(shouldSetActiveTrue: Bool) {
            let batch = db.batch()
            // Always save settings
            batch.setData(settingsData, forDocument: settingsRef, merge: true)

            // Conditionally flip active -> true (do NOT hardcode to false when not allowed)
            if shouldSetActiveTrue {
                batch.setData(["active": true,
                               "updatedAt": FieldValue.serverTimestamp()],
                              forDocument: userRef,
                              merge: true)
            }

            batch.commit { err in
                if let err = err {
                    completion?(err)
                    return
                }

                // Recompute nextSendAt; backend should honor users/{uid}.active when scheduling.
                let callable = functions.httpsCallable("applyUserSettings")
                callable.call([:]) { _, callErr in
                    completion?(callErr)
                }
            }
        }
    }
}
