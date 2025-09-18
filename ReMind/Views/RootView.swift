// =====================
// File: Views/RootView.swift
// =====================
import SwiftUI


struct RootView: View {
@EnvironmentObject private var appVM: AppViewModel


var body: some View {
Group {
if appVM.isOnboarded { MainView() } else { OnboardingView() }
}
.animation(.default, value: appVM.isOnboarded) // iOS 16-safe
}
}
