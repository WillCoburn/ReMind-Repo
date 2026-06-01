// App/AppDelegate.swift
import UIKit
import FirebaseAuth
import FirebaseCore
import SwiftUI

@objc(AppDelegate)
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private static var isPhoneAuthAPNSTokenReady = false
    private static var didFinishPhoneAuthAPNsRegistration = false
    private static var isPhoneAuthVerificationInProgress = false
    private static var pendingPhoneAuthAPNSToken: Data?
    private static var pendingPhoneAuthAPNSTokenType: AuthAPNSTokenType?
    #if DEBUG
    private static var lastPhoneAuthAPNSTokenReceivedAt: Date?
    #endif
    var window: UIWindow?
    private lazy var appVM = CompositionRoot.makeAppViewModel()
    private let net = NetworkMonitor.shared

    override init() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: "FIRDebugEnabled")
        #endif
        FirebaseBootstrap.configure()
        super.init()
    }

    // MARK: - App Launch
    @objc
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        #if DEBUG
        UserDefaults.standard.set(true, forKey: "FIRDebugEnabled")
        #endif

        // Ensure Firebase is configured before any Firebase services are used.
        FirebaseBootstrap.configure()
        _ = Auth.auth()
        #if DEBUG
        if FirebaseApp.app() == nil {
            print("❗️ FirebaseApp not configured; phone auth push handling will fail")
        } else {
            print("✅ FirebaseApp configured (\(FirebaseApp.app()?.name ?? "default"))")
        }
        print("🔥 Firebase debug logging enabled")
        #endif

        // Firebase Phone Auth asks UIApplication for an APNs token during verification.
        // Registering here can race FirebaseAuth's internal APNs setup, so we let
        // PhoneAuthProvider initiate registration when the user requests a code.
        #if DEBUG
        print("📲 Firebase Phone Auth APNs registration will be requested during verification")
        #endif
        Self.isPhoneAuthAPNSTokenReady = false
        Self.didFinishPhoneAuthAPNsRegistration = false
        configureRootWindow()

        return true
    }

    @objc
    func applicationDidBecomeActive(_ application: UIApplication) {
        NetworkMonitor.shared.forceRefresh()
        appVM.recordAppActivity(reason: "applicationDidBecomeActive")

        if appVM.isAuthInitialized {
            RevenueCatManager.shared.recomputeAndPersistActive()
            appVM.refreshRevenueCatEntitlement(reason: "applicationDidBecomeActive")
            appVM.refreshEntitlementState()
        }
    }
    
    @objc
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if DEBUG
        let tokenType: AuthAPNSTokenType = .sandbox
        #else
        let tokenType: AuthAPNSTokenType = .prod
        #endif
        let readiness = Self.firebasePhoneAuthReadiness()
        if Self.isPhoneAuthVerificationInProgress, readiness.tokenManagerReady {
            Auth.auth().setAPNSToken(deviceToken, type: tokenType)
            Self.isPhoneAuthAPNSTokenReady = true
        } else {
            Self.pendingPhoneAuthAPNSToken = deviceToken
            Self.pendingPhoneAuthAPNSTokenType = tokenType
            Self.isPhoneAuthAPNSTokenReady = false
        }
        Self.didFinishPhoneAuthAPNsRegistration = true
        #if DEBUG
        Self.lastPhoneAuthAPNSTokenReceivedAt = Date()
        print("📲 [PhoneAuth/APNs] APNs token received by app delegate. forwardedToFirebase=\(Self.isPhoneAuthVerificationInProgress && readiness.tokenManagerReady) verificationInProgress=\(Self.isPhoneAuthVerificationInProgress) tokenManagerReady=\(readiness.tokenManagerReady) notificationManagerReady=\(readiness.notificationManagerReady) type=\(tokenType) tokenBytes=\(deviceToken.count)")
        #endif
    }

    @objc
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
    @objc
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return Auth.auth().canHandle(url)
    }

    // MARK: - Remote Notification Handling (Phone Auth)
    @objc
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let readiness = Self.firebasePhoneAuthReadiness()
        guard readiness.notificationManagerReady else {
            #if DEBUG
            print("⚠️ [PhoneAuth/APNs] Silent notification arrived before FirebaseAuth notificationManager was ready. keys=\(Array(userInfo.keys))")
            #endif
            completionHandler(.noData)
            return
        }

        let handled = Auth.auth().canHandleNotification(userInfo)
        #if DEBUG
        print("📲 [PhoneAuth/APNs] Silent notification forwarded to FirebaseAuth. handled=\(handled) keys=\(Array(userInfo.keys))")
        if handled {
            print("✅ [PhoneAuth/APNs] FirebaseAuth accepted the silent verification notification; reCAPTCHA fallback should not be needed for this attempt.")
        }
        #endif
        if handled {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    @MainActor
    static func preparePhoneAuthAPNSToken() async -> Bool {
        #if DEBUG
        let delegate = UIApplication.shared.delegate
        let forwardsSilentNotifications = delegate?.responds(
            to: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
        ) ?? false
        print("📲 [PhoneAuth/APNs] Preparing FirebaseAuth phone verification. manualForwarding=true delegate=\(String(describing: delegate)) forwardsSilentNotifications=\(forwardsSilentNotifications)")
        #endif
        isPhoneAuthVerificationInProgress = true
        _ = Auth.auth()
        let readiness = await waitForFirebasePhoneAuthReadiness(timeout: 6.0)
        guard readiness.tokenManagerReady, readiness.notificationManagerReady, readiness.appCredentialManagerReady else {
            #if DEBUG
            print("⚠️ [PhoneAuth/APNs] FirebaseAuth phone internals were not ready before verification. tokenManagerReady=\(readiness.tokenManagerReady) notificationManagerReady=\(readiness.notificationManagerReady) appCredentialManagerReady=\(readiness.appCredentialManagerReady) labels=\(readiness.availableAuthStorageLabels)")
            #endif
            return false
        }

        if let pendingPhoneAuthAPNSToken, let pendingPhoneAuthAPNSTokenType {
            Auth.auth().setAPNSToken(pendingPhoneAuthAPNSToken, type: pendingPhoneAuthAPNSTokenType)
            isPhoneAuthAPNSTokenReady = true
            Self.pendingPhoneAuthAPNSToken = nil
            Self.pendingPhoneAuthAPNSTokenType = nil
            #if DEBUG
            print("📲 [PhoneAuth/APNs] Pending APNs token forwarded after FirebaseAuth became ready. type=\(pendingPhoneAuthAPNSTokenType) tokenBytes=\(pendingPhoneAuthAPNSToken.count)")
            #endif
        }

        let proberNotification: [AnyHashable: Any] = [
            "com.google.firebase.auth": [
                "warning": "This fake notification should be forwarded to Firebase Auth."
            ]
        ]
        let handledProbe = Auth.auth().canHandleNotification(proberNotification)

        #if DEBUG
        let elapsedSinceToken = lastPhoneAuthAPNSTokenReceivedAt.map { String(format: "%.2fs", Date().timeIntervalSince($0)) } ?? "n/a"
        print("📲 [PhoneAuth/APNs] Verification prep finished. notificationProbeHandled=\(handledProbe) tokenReady=\(isPhoneAuthAPNSTokenReady) registrationFinished=\(didFinishPhoneAuthAPNsRegistration) tokenAge=\(elapsedSinceToken)")
        #endif
        return handledProbe
    }

    static func finishPhoneAuthAPNSTokenAttempt() {
        isPhoneAuthVerificationInProgress = false
    }

    private func configureRootWindow() {
        guard window == nil else { return }

        let rootView = RootView()
            .environmentObject(appVM)
            .environmentObject(net)

        let hostingController = UIHostingController(rootView: rootView)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        self.window = window

        #if DEBUG
        print("📲 UIKit AppDelegate root window configured. delegate=\(String(describing: UIApplication.shared.delegate))")
        #endif
    }

    private struct FirebasePhoneAuthReadiness {
        let tokenManagerReady: Bool
        let notificationManagerReady: Bool
        let appCredentialManagerReady: Bool
        let availableAuthStorageLabels: [String]

        var isReady: Bool {
            tokenManagerReady && notificationManagerReady && appCredentialManagerReady
        }
    }

    @MainActor
    private static func waitForFirebasePhoneAuthReadiness(timeout: TimeInterval) async -> FirebasePhoneAuthReadiness {
        let startedAt = Date()
        var lastReadiness = firebasePhoneAuthReadiness()
        var lastStateDescription = ""

        while Date().timeIntervalSince(startedAt) < timeout {
            lastReadiness = firebasePhoneAuthReadiness()
            let stateDescription = "\(lastReadiness.tokenManagerReady)-\(lastReadiness.notificationManagerReady)-\(lastReadiness.appCredentialManagerReady)"
            #if DEBUG
            if stateDescription != lastStateDescription {
                let elapsed = String(format: "%.2fs", Date().timeIntervalSince(startedAt))
                print("📲 [PhoneAuth/APNs] FirebaseAuth readiness after \(elapsed): tokenManager=\(lastReadiness.tokenManagerReady) notificationManager=\(lastReadiness.notificationManagerReady) appCredentialManager=\(lastReadiness.appCredentialManagerReady)")
                lastStateDescription = stateDescription
            }
            #endif
            if lastReadiness.isReady {
                return lastReadiness
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return lastReadiness
    }

    private static func firebasePhoneAuthReadiness() -> FirebasePhoneAuthReadiness {
        let auth = Auth.auth()
        let children = Mirror(reflecting: auth).children
        var labels: [String] = []
        var tokenManagerReady = false
        var notificationManagerReady = false
        var appCredentialManagerReady = false

        for child in children {
            guard let label = child.label else { continue }
            labels.append(label)
            switch label {
            case "tokenManager":
                tokenManagerReady = !isNilOptional(child.value)
            case "notificationManager":
                notificationManagerReady = !isNilOptional(child.value)
            case "appCredentialManager":
                appCredentialManagerReady = !isNilOptional(child.value)
            default:
                break
            }
        }

        return FirebasePhoneAuthReadiness(
            tokenManagerReady: tokenManagerReady,
            notificationManagerReady: notificationManagerReady,
            appCredentialManagerReady: appCredentialManagerReady,
            availableAuthStorageLabels: labels
        )
    }

    private static func isNilOptional(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional && mirror.children.isEmpty
    }
}
