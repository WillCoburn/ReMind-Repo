
// =========================
// File: App/ReMindApp.swift
// =========================
import SwiftUI


@main
struct ReMindApp: App {
    // Hook in AppDelegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // existing view model setup
    @StateObject private var appVM = CompositionRoot.makeAppViewModel()


var body: some Scene {
WindowGroup {
RootView()
.environmentObject(appVM)
}
}
}
