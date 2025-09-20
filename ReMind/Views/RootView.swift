// Views/RootView.swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appVM: AppViewModel

    var body: some View {
        Group {
            if appVM.isOnboarded {
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
        .animation(.default, value: appVM.isOnboarded)
        // Remove the undefined FirebasePing call (or keep it debug-only if you add the helper)
        // .onAppear { FirebasePing.writeHello() }
    }
}
