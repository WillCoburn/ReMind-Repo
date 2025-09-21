// =====================
// File: Views/RootView.swift
// =====================
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        Group {
            if appVM.user != nil {
                NavigationView {
                    MainView()
                        .navigationTitle("ReMind")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Log Out") { appVM.logout() }
                            }
                        }
                }
            } else {
                OnboardingView()
            }
        }
        // animate when user logs in/out
        .animation(.default, value: appVM.user != nil)
    }
}
