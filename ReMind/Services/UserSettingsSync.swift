// ==================================
// File: Services/UserSettingsSync.swift
// ==================================
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

struct UserSettings: Codable {
    var remindersPerWeek: Double
    var tzIdentifier: String
    var quietStartHour: Int    // 0...24
    var quietEndHour: Int      // 0...24
}

enum UserSettingsSync {

    // MARK: - Read from AppStorage

    static func currentFromAppStorage() -> UserSettings {
        let d = UserDefaults.standard

        let storedWeekly = d.object(forKey: "remindersPerWeek") as? Double
        let legacyDaily = d.object(forKey: "remindersPerDay") as? Double

        var weekly =
            storedWeekly ??
            ((legacyDaily != nil) ? (legacyDaily! * 7.0) : nil) ??
            7.0

        weekly = max(1.0, min(20.0, weekly))

        if storedWeekly == nil {
            d.set(weekly, forKey: "remindersPerWeek")
        }

        return .init(
            remindersPerWeek: weekly,
            tzIdentifier: d.string(forKey: "tzIdentifier")
                ?? TimeZone.current.identifier,
            quietStartHour: max(
                0,
                min(24, Int(round(d.double(forKey: "quietStartHour"))))
            ),
            quietEndHour: max(
                0,
                min(24, Int(round(d.double(forKey: "quietEndHour"))))
            )
        )
    }

    // MARK: - Push + Apply (ASYNC / AWAIT SAFE)

    /// Writes settings to Firestore at users/{uid}/meta/settings
    /// THEN calls the callable `applyUserSettings`
    ///
    /// `active` is only flipped to true if:
    /// - subscribed
    /// - OR still within trial
    static func pushAndApply() async throws {
        print("🧪 settings save tapped")
        print("🧪 settings uid:", Auth.auth().currentUser?.uid ?? "nil")

        try await Task.detached(priority: .userInitiated) {
            guard let uid = Auth.auth().currentUser?.uid else {
                throw NSError(
                    domain: "UserSettingsSync",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Not logged in"]
                )
            }

            let db = Firestore.firestore()
            let functions = Functions.functions()
            let settings = currentFromAppStorage()

            let settingsData: [String: Any] = [
                "remindersPerWeek": settings.remindersPerWeek,
                "tzIdentifier": settings.tzIdentifier,
                "quietStartHour": settings.quietStartHour,
                "quietEndHour": settings.quietEndHour,
                "updatedAt": FieldValue.serverTimestamp()
            ]

            let userRef = db.collection("users").document(uid)
            let settingsRef = userRef
                .collection("meta")
                .document("settings")

            // MARK: - Read user state (subscription / trial)

            let snapshot = try await withTimeout(seconds: 3, label: "settings getDocument") {
                try await runOffMain(label: "settings getDocument") {
                    try await userRef.getDocument()
                }
            }

            var shouldSetActiveTrue = false
            if snapshot.exists {
                let status =
                    (snapshot.get("subscriptionStatus") as? String)
                    ?? SubscriptionStatus.unsubscribed.rawValue

                let isSubscribed =
                    status == SubscriptionStatus.subscribed.rawValue

                let trialEndsAt =
                    (snapshot.get("trialEndsAt") as? Timestamp)?.dateValue()

                let withinTrial =
                    trialEndsAt.map { Date() < $0 } ?? false

                shouldSetActiveTrue = isSubscribed || withinTrial
            }

            // MARK: - Batch write (cannot be cancelled)

            let batch = db.batch()

            batch.setData(
                settingsData,
                forDocument: settingsRef,
                merge: true
            )

            if shouldSetActiveTrue {
                batch.setData(
                    [
                        "active": true,
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: userRef,
                    merge: true
                )
            }

            try await withTimeout(seconds: 3, label: "settings batch commit") {
                try await runOffMain(label: "settings batch commit") {
                    try await batch.commit()
                }
            }
            print("✅ settings batch COMMITTED")

            // MARK: - Callable

            let callable = functions.httpsCallable("applyUserSettings")
            _ = try await withTimeout(seconds: 3, label: "applyUserSettings callable") {
                try await runOffMain(label: "applyUserSettings callable") {
                    try await callable.call([:])
                }
            }
            print("✅ applyUserSettings success")
        }.value
    }
}
