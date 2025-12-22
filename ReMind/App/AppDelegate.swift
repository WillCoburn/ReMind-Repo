// App/AppDelegate.swift
import UIKit
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - App Launch
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {


        // Enable Firebase debug logging (optional)
        UserDefaults.standard.set(true, forKey: "FIRDebugEnabled")
        print("🔥 Firebase debug logging enabled")

        // Required for Firebase Phone Auth silent verification
        application.registerForRemoteNotifications()

        return true
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
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }
}
