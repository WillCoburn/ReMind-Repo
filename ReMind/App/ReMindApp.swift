// ============================
// File: App/ReMindApp.swift
// ============================
import SwiftUI

@main
struct ReMindApp: App {

    // ✅ REQUIRED so Firebase can swizzle AppDelegate for Phone Auth / APNs
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    @StateObject private var appVM: AppViewModel
    @StateObject private var net = NetworkMonitor.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _appVM = StateObject(wrappedValue: CompositionRoot.makeAppViewModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appVM)
                .environmentObject(net)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }

            NetworkMonitor.shared.forceRefresh()

            if appVM.isAuthInitialized {
                RevenueCatManager.shared.recomputeAndPersistActive()
                appVM.refreshRevenueCatEntitlement()
                appVM.refreshEntitlementState()
            }
        }

    }
}
