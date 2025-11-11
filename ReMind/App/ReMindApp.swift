// App/ReMindApp.swift
import SwiftUI

@main
struct ReMindApp: App {
    // If you need AppDelegate for phone auth/APNs handoff:
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appVM = CompositionRoot.makeAppViewModel()
    
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var net = NetworkMonitor.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appVM)
                .environmentObject(net)
                // 🧩 Initialize RevenueCat once UI is up (after Firebase init in AppDelegate)
                .onAppear {
                    RevenueCatManager.shared.configure()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                NetworkMonitor.shared.forceRefresh()
                // 🔁 Recompute `active` when app comes to foreground (handles trial rollovers)
                RevenueCatManager.shared.recomputeAndPersistActive()
            }
        }
    }
}
