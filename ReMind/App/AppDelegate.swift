// App/AppDelegate.swift
import UIKit
import FirebaseAuth
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - App Launch
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // Ensure Firebase is configured before any Firebase services are used
        FirebaseBootstrap.configure()
        if FirebaseApp.app() == nil {
            print("❗️ FirebaseApp not configured; phone auth push handling will fail")
        } else {
            print("✅ FirebaseApp configured (\(FirebaseApp.app()?.name ?? "default"))")
        }
        // Enable Firebase debug logging (optional)
        UserDefaults.standard.set(true, forKey: "FIRDebugEnabled")
        print("🔥 Firebase debug logging enabled")

        // Required for Firebase Phone Auth silent verification
        print("📲 Registering for remote notifications for Firebase Phone Auth")
        application.registerForRemoteNotifications()

        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("✅ Successfully registered for remote notifications. Token length: \(deviceToken.count) bytes")
    }

    // MARK: - URL Handling (Phone Auth reCAPTCHA / fallback)
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return Auth.auth().canHandle(url)
    }

    // MARK: - Remote Notification Handling (Phone Auth)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let handled = Auth.auth().canHandleNotification(userInfo)
        print("📲 [APNs] Forwarded to FirebaseAuth.canHandleNotification: handled=\(handled), keys=\(Array(userInfo.keys))")
        if handled {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }
}
