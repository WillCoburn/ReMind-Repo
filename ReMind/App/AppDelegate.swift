// App/AppDelegate.swift
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

class AppDelegate: NSObject, UIApplicationDelegate {



    // MARK: - App Launch
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()

        FirebaseBootstrap.configure()

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
