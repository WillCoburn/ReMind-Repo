// ============================
// File: App/ReMindApp.swift
// ============================
import SwiftUI
import FirebaseAuth

@main
struct ReMindApp: App {
    // If you need AppDelegate for phone auth/APNs handoff:
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appVM: AppViewModel
    @StateObject private var paywallPresenter = PaywallPresenter()

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var net = NetworkMonitor.shared

    init() {
        FirebaseBootstrap.configure()
        _appVM = StateObject(wrappedValue: CompositionRoot.makeAppViewModel())
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appVM)
                .environmentObject(net)
                .environmentObject(paywallPresenter)
                // ❌ Removed eager RC configure on launch.
                // RC is now lazily configured when we explicitly identify/restore.
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                NetworkMonitor.shared.forceRefresh()
                // Recompute only if we’re identified (lazy manager will no-op otherwise).
                RevenueCatManager.shared.recomputeAndPersistActive()
                appVM.refreshEntitlementState()
            }
        }
    }
}



