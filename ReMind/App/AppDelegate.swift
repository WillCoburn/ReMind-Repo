// App/AppDelegate.swift
import UIKit
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Safe to call; no permission alert. Needed so Firebase can try APNs verification.
        application.registerForRemoteNotifications()

        return true
    }

    // Handle the reCAPTCHA/phone-auth redirect back into the app
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) { return true }
        return false
    }

    // --- Explicit forwarding for when swizzling is off (or unreliable) ---

    // Pass APNs token to Firebase Auth
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // .sandbox on debug device builds, .prod for TestFlight/App Store; .unknown also works
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    // Forward remote notifications to Firebase Auth (async variant)
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        if Auth.auth().canHandleNotification(userInfo) {
            return .noData
        }
        return .noData
    }

    // If you prefer the non-async signature, use this instead:
    // func application(_ application: UIApplication,
    //                  didReceiveRemoteNotification userInfo: [AnyHashable : Any],
    //                  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    //     if Auth.auth().canHandleNotification(userInfo) {
    //         completionHandler(.noData)
    //         return
    //     }
    //     completionHandler(.noData)
    // }
}
