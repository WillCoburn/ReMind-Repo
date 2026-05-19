// ==================================
// File: Services/UserSettingsSync.swift
// ==================================
import Foundation
import FirebaseAuth
import FirebaseFunctions


struct UserSettings: Codable, Sendable {
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
            3.0

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
    /// In freemium, settings updates no longer depend on trial/entitlement state.
    static func pushAndApply(
        settings: UserSettings = currentFromAppStorage(),
        expectedUid: String? = nil,
        clientRevision: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) async throws {
        print("🧪 settings save tapped")
        print("🧪 settings uid:", Auth.auth().currentUser?.uid ?? "nil")
        
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(
                domain: "UserSettingsSync",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not logged in"]
            )
        }

        if let expectedUid, expectedUid != uid {
            throw CancellationError()
        }

        let settingsData: [String: Any] = [
            "remindersPerWeek": settings.remindersPerWeek,
            "tzIdentifier": settings.tzIdentifier,
            "quietStartHour": settings.quietStartHour,
            "quietEndHour": settings.quietEndHour
        ]

        let functions = Functions.functions()
        let callable = functions.httpsCallable("applyUserSettings")
        _ = try await callable.call([
            "settings": settingsData,
            "clientRevision": clientRevision
        ])

        if let expectedUid, Auth.auth().currentUser?.uid != expectedUid {
            throw CancellationError()
        }

        print("✅ applyUserSettings success")
    }
}
