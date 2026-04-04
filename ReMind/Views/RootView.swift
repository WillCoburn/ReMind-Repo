// =====================
// File: Views/RootView.swift
// =====================
import SwiftUI
import FirebaseAuth

struct RootView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @AppStorage("hasCompletedOrientationSlides") private var hasCompletedOrientationSlides = false

    // Which horizontal page we’re on
    private enum Page: Hashable { case community, main, right }
    @State private var activePage: Page = .main
    @State private var orientationStep: AppViewModel.FeatureTourStep = .settings
    
    /// New launch flow gate:
    /// 1) Orientation slides (once, pre-auth)
    /// 2) Phone auth onboarding (if needed)
    /// 3) Main app
    private var shouldShowOrientationSlides: Bool {
        guard appVM.hasLoadedInitialProfile else { return false }
        // Legacy migration: if Firestore already says the user saw the tour, don't show slides again.
        if appVM.hasSeenFeatureTour { return false }
        return !hasCompletedOrientationSlides
    }
    
    
    var body: some View {
        Group {
            if !appVM.hasLoadedInitialProfile {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if shouldShowOrientationSlides {
                FeatureTourOverlay(
                    step: $orientationStep,
                    onComplete: { completeOrientationSlides() },
                    onSkip: { completeOrientationSlides() }
                )
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
                    
                    
                    // Feature tour overlay (only on main page)
                    if appVM.showFeatureTour, activePage == .main, !hasCompletedOrientationSlides {
                        FeatureTourOverlay(
                            step: Binding(
                                get: { appVM.featureTourStep },
                                set: { appVM.featureTourStep = $0 }
                            ),
                            onComplete: {
                                Task { await appVM.completeFeatureTour(markAsSeen: true) }
                            },
                            onSkip: {
                                Task { await appVM.skipFeatureTour() }
                            }
                        )
                        .transition(.opacity)
                        .zIndex(2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        // Animate when the onboarding gate flips
        .animation(.default, value: appVM.shouldShowOnboarding)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appVM.featureTourStep)
        .animation(.easeInOut(duration: 0.25), value: appVM.showFeatureTour)
        .networkAware()
        .onAppear {
            Auth.auth().addStateDidChangeListener { _, user in
                print("🔐 auth changed uid:", user?.uid ?? "nil")
            }

            // One-time migration for returning users who already completed the
            // older in-app tour before this flow change.
            if appVM.hasSeenFeatureTour && !hasCompletedOrientationSlides {
                hasCompletedOrientationSlides = true
            }
        }

        
        // Always drop users into the main page once onboarding finishes
        .onChange(of: appVM.shouldShowOnboarding) { shouldShow in
            if !shouldShow {
                activePage = .main
            }
        }
        .onChange(of: appVM.hasSeenFeatureTour) { hasSeen in
            if hasSeen && !hasCompletedOrientationSlides {
                hasCompletedOrientationSlides = true
            }
        }



        // Dismiss keyboard if user swipes away from the main page
        .onChange(of: activePage) { newPage in
            guard newPage != .main else { return }
            hideKeyboard()
        }
    }
    
    private func completeOrientationSlides() {
        hasCompletedOrientationSlides = true
        orientationStep = .settings
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
        // Keep bottom overlays (like MainView's action bar) pinned even when the keyboard shows
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
    
    @ViewBuilder
    private var mainPage: some View {
        MainView()
        
    }
    
}
