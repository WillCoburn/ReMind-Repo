// App/AppDelegate.swift
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Debug Helper
    private func debugFirebaseConfig() {
        if let app = FirebaseApp.app() {
            print("🔥 Firebase app name:", app.name)
            print("🔥 Firebase projectID:", app.options.projectID ?? "nil")
            print("🔥 Firebase apiKey:", app.options.apiKey)
        } else {
            print("🔥 Firebase app is nil")
        }

        // These just confirm Firestore / Functions are initialized, no extra properties
        _ = Firestore.firestore()
        _ = Functions.functions()
        print("🔥 Firestore & Functions initialized")
    }

    // MARK: - App Launch
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()

        // Print out what Firebase project you're actually connecting to
        debugFirebaseConfig()

        // Enable debug logging for Functions
        UserDefaults.standard.set(true, forKey: "FIRDebugEnabled")
        print("🔥 Firebase Functions debug logging enabled")

        // Needed so Firebase can attempt APNs verification safely
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - URL Handling (Phone Auth)
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        if Auth.auth().canHandle(url) { return true }
        return false
    }

    // MARK: - APNs Token Forwarding
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    // MARK: - Remote Notification Handling
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any]
    ) async -> UIBackgroundFetchResult {
        if Auth.auth().canHandleNotification(userInfo) {
            return .noData
        }
        return .noData
    }
}
