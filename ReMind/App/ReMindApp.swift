// App/ReMindApp.swift
import SwiftUI

@main
struct ReMindApp: App {
    // If you need AppDelegate for phone auth/APNs handoff:
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appVM = CompositionRoot.makeAppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appVM)
        }
    }
}
