// ==================================
// File: Services/UserSettingsSync.swift
// ==================================
import Foundation
import FirebaseAuth
import FirebaseFirestore

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
            remindersPerDay: max(0.1, min(5.0, d.double(forKey: "remindersPerDay"))),
            tzIdentifier: d.string(forKey: "tzIdentifier") ?? TimeZone.current.identifier,
            quietStartHour: Int(round(d.double(forKey: "quietStartHour"))),
            quietEndHour: Int(round(d.double(forKey: "quietEndHour")))
        )
    }

    /// Writes settings to Firestore at users/{uid}/settings and triggers a callable to recompute nextSendAt.
    static func pushAndApply(completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "UserSettingsSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not logged in"]))
            return
        }

        let db = Firestore.firestore()
        let settings = currentFromAppStorage()
        let data: [String: Any] = [
            "remindersPerDay": settings.remindersPerDay,
            "tzIdentifier": settings.tzIdentifier,
            "quietStartHour": settings.quietStartHour,
            "quietEndHour": settings.quietEndHour,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let userRef = db.collection("users").document(uid)
        let settingsRef = userRef.collection("meta").document("settings")

        db.runTransaction({ txn, _ -> Any? in
            txn.setData(["active": true], forDocument: userRef, merge: true)
            txn.setData(data, forDocument: settingsRef, merge: true)
            return nil
        }) { _, err in
            if let err { completion?(err); return }
            // Optionally call a callable function to recompute nextSendAt immediately
            // If you already use FirebaseFunctions in the app, you can uncomment:
            //
            // Functions.functions().httpsCallable("applyUserSettings").call([:]) { _, _ in
            //     completion?(nil)
            // }
            completion?(nil)
        }
    }
}
