
// =========================
// File: App/ReMindApp.swift
// =========================
import SwiftUI


@main
struct ReMindApp: App {
@StateObject private var appVM = CompositionRoot.makeAppViewModel()


var body: some Scene {
WindowGroup {
RootView()
.environmentObject(appVM)
}
}
}
