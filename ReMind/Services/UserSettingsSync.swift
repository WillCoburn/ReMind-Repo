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
    static func pushAndApply(completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "UserSettingsSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not logged in"]))
            return
        }

        let db = Firestore.firestore()
        let s = currentFromAppStorage()
        let data: [String: Any] = [
            "remindersPerDay": s.remindersPerDay,
            "tzIdentifier": s.tzIdentifier,
            "quietStartHour": s.quietStartHour,
            "quietEndHour": s.quietEndHour,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let userRef = db.collection("users").document(uid)
        let settingsRef = userRef.collection("meta").document("settings")

        // 1) Write settings (batch)
        let batch = db.batch()
        batch.setData(["active": true], forDocument: userRef, merge: true)
        batch.setData(data, forDocument: settingsRef, merge: true)
        batch.commit { err in
            if let err = err {
                completion?(err)
                return
            }

            // 2) Call backend to compute nextSendAt now (Option 1)
            let callable = Functions.functions().httpsCallable("applyUserSettings")
            callable.call([:]) { _, callErr in
                // Even if the callable fails, the settings are saved; surface error if any.
                completion?(callErr)
            }
        }
    }
}
