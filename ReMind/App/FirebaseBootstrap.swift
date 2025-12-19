// ============================
// File: App/FirebaseBootstrap.swift
// ============================
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

enum FirebaseBootstrap {
    private static var hasConfigured = false
    private static let projectCacheKey = "FirebaseProjectId"
    private static let defaultFirestoreHost = "firestore.googleapis.com"

    /// Ensures Firebase is configured exactly once and eagerly prepares Firestore
    /// so gRPC streams are online before any async work is launched.
    static func configure() {
        guard !hasConfigured else { return }
        hasConfigured = true
        
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        FirebaseConfiguration.shared.setLoggerLevel(.debug)

        Task.detached(priority: .userInitiated) {
            await logRuntimeConfiguration()
            await resetPersistenceIfProjectChanged()
            await ensureFirestoreNetworkEnabled()
            await sanityCheckConnectivity()
            await logAuthState()
        }
    }

    // MARK: - Diagnostics
    private static func logRuntimeConfiguration() async {
        guard let app = FirebaseApp.app() else {
            print("🔥 Firebase app is nil")
            return
        }

        let options = app.options
        let bundleID = Bundle.main.bundleIdentifier ?? "nil"
        print("🔥 Firebase app name:", app.name)
        print("🔥 Firebase projectID:", options.projectID ?? "nil")
        print("🔥 Firebase appID:", options.googleAppID)
        print("🔥 Firebase bundleID:", options.bundleID ?? "nil", "(main bundle:", bundleID, ")")

        let db = Firestore.firestore()
        let settings = db.settings
        let host = settings.host
        let emulatorEnv = ProcessInfo.processInfo.environment["FIRESTORE_EMULATOR_HOST"]
        let usingEmulator = (host != defaultFirestoreHost) || (emulatorEnv != nil)
        print("🔥 Firestore host:", host)
        print("🔥 Firestore SSL:", settings.isSSLEnabled)
        print("🔥 Firestore persistence:", settings.isPersistenceEnabled)
        print("🔥 Firestore emulator env:", emulatorEnv ?? "nil")
        print("🔥 Firestore using emulator:", usingEmulator)
    }

    private static func logAuthState() async {
        guard let user = Auth.auth().currentUser else {
            print("🔥 Firebase Auth user: nil")
            return
        }

        do {
            let token = try await user.getIDTokenResult()
            let prefix = token.token.prefix(8)
            print("🔥 Firebase Auth uid:", user.uid)
            print("🔥 Firebase Auth token prefix:", prefix)
        } catch {
            print("❌ getIDTokenResult failed:", error.localizedDescription)
        }
    }

    // MARK: - Remediation
    /// If the bundled Firebase project changed (e.g., switching envs), clear the
    /// on-device Firestore cache to avoid stale stream state from the prior app.
    private static func resetPersistenceIfProjectChanged() async {
        guard let projectID = FirebaseApp.app()?.options.projectID else { return }
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: projectCacheKey)

        guard previous != projectID else { return }

        do {
            try await Firestore.firestore().clearPersistence()
            print("🔥 Cleared Firestore persistence due to project change", previous ?? "nil", "→", projectID)
        } catch {
            print("❌ Failed to clear Firestore persistence:", error.localizedDescription)
        }

        defaults.set(projectID, forKey: projectCacheKey)
    }

    /// Firestore can remain stuck offline if a prior disableNetwork was issued or
    /// if the cache was corrupted; explicitly re-enable networking at launch.
    private static func ensureFirestoreNetworkEnabled() async {
        let db = Firestore.firestore()
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                db.enableNetwork { error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
            print("🔥 Firestore network enabled")
        } catch {
            print("❌ Failed to enable Firestore network:", error.localizedDescription)
        }
    }

    // MARK: - Connectivity sanity check
     private static func sanityCheckConnectivity() async {
         guard let uid = Auth.auth().currentUser?.uid else {
             print("🔥 Firestore sanity check skipped: no auth user yet")
             return
         }

         let db = Firestore.firestore()
         let pingRef = db.collection("users")
             .document(uid)
             .collection("meta")
             .document("debug")
             .collection("ping")
             .document("boot")

         do {
             try await withTimeout(seconds: 5, label: "firestore ping write") {
                 try await runOffMain(label: "firestore ping write") {
                     try await pingRef.setData([
                         "ts": FieldValue.serverTimestamp(),
                         "source": "bootstrap"
                     ])
                 }
             }

             let snapshot = try await withTimeout(seconds: 5, label: "firestore ping read") {
                 try await runOffMain(label: "firestore ping read") {
                     try await pingRef.getDocument()
                 }
             }

             let ts = (snapshot.get("ts") as? Timestamp)?.dateValue()
             print("✅ Firestore sanity check ok (ts: \(ts?.description ?? "nil"))")
         } catch {
             print("❌ Firestore sanity check failed:", error.localizedDescription)
         }
     }
    
}
