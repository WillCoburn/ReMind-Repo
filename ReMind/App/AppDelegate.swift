// App/AppDelegate.swift
import UIKit
import FirebaseAuth
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    private static var isPhoneAuthAPNSTokenReady = false
    private static var didFinishPhoneAuthAPNsRegistration = false

    // MARK: - App Launch
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // Ensure Firebase is configured before any Firebase services are used
        FirebaseBootstrap.configure()
        #if DEBUG
        if FirebaseApp.app() == nil {
            print("❗️ FirebaseApp not configured; phone auth push handling will fail")
        } else {
            print("✅ FirebaseApp configured (\(FirebaseApp.app()?.name ?? "default"))")
        }
        UserDefaults.standard.set(true, forKey: "FIRDebugEnabled")
        print("🔥 Firebase debug logging enabled")
        #endif

        // Required for Firebase Phone Auth silent verification
        #if DEBUG
        print("📲 Registering for remote notifications for Firebase Phone Auth")
        #endif
        Self.isPhoneAuthAPNSTokenReady = false
        Self.didFinishPhoneAuthAPNsRegistration = false
        application.registerForRemoteNotifications()

        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if DEBUG
        let tokenType: AuthAPNSTokenType = .sandbox
        #else
        let tokenType: AuthAPNSTokenType = .prod
        #endif
        Auth.auth().setAPNSToken(deviceToken, type: tokenType)
        Self.isPhoneAuthAPNSTokenReady = true
        Self.didFinishPhoneAuthAPNsRegistration = true
        #if DEBUG
        print("✅ Successfully registered for remote notifications. Token length: \(deviceToken.count) bytes")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Self.isPhoneAuthAPNSTokenReady = false
        Self.didFinishPhoneAuthAPNsRegistration = true
        #if DEBUG
        print("❌ Failed to register for remote notifications:", error.localizedDescription)
        #endif
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
        #if DEBUG
        print("📲 [APNs] Forwarded to FirebaseAuth.canHandleNotification: handled=\(handled), keys=\(Array(userInfo.keys))")
        #endif
        if handled {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    @MainActor
    static func waitForPhoneAuthAPNSToken(timeout: TimeInterval = 2.0) async -> Bool {
        guard !isPhoneAuthAPNSTokenReady else { return true }

        let deadline = Date().addingTimeInterval(timeout)
        while !isPhoneAuthAPNSTokenReady && !didFinishPhoneAuthAPNsRegistration && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return isPhoneAuthAPNSTokenReady
    }
}
