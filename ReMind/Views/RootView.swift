// =====================
// File: Views/RootView.swift
// =====================
import SwiftUI
import PhotosUI

struct RootView: View {
    @EnvironmentObject private var appVM: AppViewModel

    // Which horizontal page we’re on
    private enum Page: Hashable { case community, main, right }
    @State private var activePage: Page = .main

    // Settings UI state
    @State private var showSettings = false

    // Persisted settings (simple local storage for now)
    @AppStorage("remindersPerWeek") private var remindersPerWeek: Double = 7.0 // 1...20
    @AppStorage("tzIdentifier")    private var tzIdentifier: String = TimeZone.current.identifier
    @AppStorage("quietStartHour")  private var quietStartHour: Double = 9     // 0...23
    @AppStorage("quietEndHour")    private var quietEndHour: Double = 22      // 0...23

    // Background image (still stored here so settings can edit it)
    @AppStorage("bgImageBase64")   private var bgImageBase64: String = ""

    var body: some View {
        Group {
            if !appVM.hasLoadedInitialProfile {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appVM.shouldShowOnboarding {
                OnboardingView()
            } else {
                ZStack(alignment: .top) {
                    // Global background is just system color now.
                    // The user photo is handled *inside MainView* only.
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()

                    // Horizontal pager: Community ← Main → Right
                    pager

                    // Slide-down settings panel overlay (only on main page)
                    if showSettings, activePage == .main {
                        UserSettingsPanel(
                            remindersPerWeek: $remindersPerWeek,
                            tzIdentifier: $tzIdentifier,
                            quietStartHour: $quietStartHour,
                            quietEndHour: $quietEndHour,
                            bgImageBase64: $bgImageBase64,
                            onClose: {
                                closeSettingsPanel()
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                    }

                    // Feature tour overlay (only on main page)
                    if appVM.showFeatureTour, activePage == .main {
                        FeatureTourOverlay(
                            step: appVM.featureTourStep,
                            onNext: {
                                Task { await appVM.advanceFeatureTour() }
                            },
                            onSkip: {
                                Task { await appVM.skipFeatureTour() }
                            }
                        )
                        .transition(.opacity)
                        .zIndex(2)
                    }
                }
            }
        }
        // Animate when the onboarding gate flips
        .animation(.default, value: appVM.shouldShowOnboarding)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appVM.featureTourStep)
        .animation(.easeInOut(duration: 0.25), value: appVM.showFeatureTour)
    }

    // MARK: - Pager (3 horizontal screens)

    private var pager: some View {
        TabView(selection: $activePage) {
            // LEFT: Community
            NavigationStack {
                CommunityView()
            }
            .tag(Page.community)

            // CENTER: main page (your existing MainView with toolbar)
            NavigationStack {
                mainPage
            }
            .tag(Page.main)

            // RIGHT: placeholder for future stuff
            NavigationStack {
                RightPanelPlaceholderView()
            }
            .tag(Page.right)
        }
        .tabViewStyle(.page(indexDisplayMode: .never)) // Snapchat-style swipe
    }

    @ViewBuilder
    private var mainPage: some View {
        MainView()
            .overlay {
                if showSettings {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea(edges: [.horizontal, .bottom])
                        .transition(.opacity)
                        .onTapGesture { closeSettingsPanel() }
                }
            }
            .navigationTitle("ReMind")
            .toolbar {
                // Settings button (top-right)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        toggleSettingsPanel()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                            .accessibilityLabel("Settings")
                    }
                }
            }
    }

    private func toggleSettingsPanel() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showSettings.toggle()
        }
    }

    private func closeSettingsPanel() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showSettings = false
        }
        // Persist settings to Firestore so backend can schedule sends
        UserSettingsSync.pushAndApply { err in
            print("pushAndApply ->", err?.localizedDescription ?? "OK")
        }
    }
}
