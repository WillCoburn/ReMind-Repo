// =====================
// File: Views/RootView.swift
// =====================
import SwiftUI
import FirebaseAuth

struct RootView: View {
    @EnvironmentObject private var appVM: AppViewModel

    // Which horizontal page we’re on
    private enum Page: Hashable { case community, main, right }
    @State private var activePage: Page = .main
    @State private var showOnboardingFeatureTour: Bool = true
    @State private var hasDismissedOnboardingFeatureTour: Bool = false
    @State private var authDebugHandle: AuthStateDidChangeListenerHandle?


    var body: some View {
        Group {
#if DEBUG
            if let debugScreen = BrainMailDebugLaunchRoute.requestedScreen {
                debugView(for: debugScreen)
            } else {
                appContent
            }
#else
            appContent
#endif
        }
        // Animate when the onboarding gate flips
        .animation(.default, value: appVM.shouldShowOnboarding)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appVM.featureTourStep)
        .animation(.easeInOut(duration: 0.25), value: showOnboardingFeatureTour)
        .networkAware()
        .onAppear {
            if authDebugHandle == nil {
                authDebugHandle = Auth.auth().addStateDidChangeListener { _, user in
                    print("🔐 auth changed uid:", user?.uid ?? "nil")
                }
            }

            if appVM.shouldShowOnboarding && !hasDismissedOnboardingFeatureTour {
                appVM.featureTourStep = .settings
                showOnboardingFeatureTour = true
            }
        }
        .onDisappear {
            if let authDebugHandle {
                Auth.auth().removeStateDidChangeListener(authDebugHandle)
                self.authDebugHandle = nil
            }
        }


        // Always drop users into the main page once onboarding finishes
        .onChange(of: appVM.shouldShowOnboarding) { shouldShow in
            if shouldShow {
                if !hasDismissedOnboardingFeatureTour {
                    appVM.featureTourStep = .settings
                    showOnboardingFeatureTour = true
                }
            } else {
                activePage = .main
                showOnboardingFeatureTour = false
            }
        }



        // Dismiss keyboard if user swipes away from the main page
        .onChange(of: activePage) { newPage in
            guard newPage != .main else { return }
            hideKeyboard()
        }
    }

    @ViewBuilder
    private var appContent: some View {
        if !appVM.hasLoadedInitialProfile {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appVM.shouldShowOnboarding {
            ZStack {
                OnboardingView(
                    onReturnToFeatureTour: {
                        appVM.featureTourStep = .phoneNumber
                        hasDismissedOnboardingFeatureTour = false
                        showOnboardingFeatureTour = true
                    }
                )

                if showOnboardingFeatureTour {
                    FeatureTourOverlay(
                        step: Binding(
                            get: { appVM.featureTourStep },
                            set: { appVM.featureTourStep = $0 }
                        ),
                        onComplete: {
                            hasDismissedOnboardingFeatureTour = true
                            showOnboardingFeatureTour = false
                        },
                        onSkip: {
                            hasDismissedOnboardingFeatureTour = true
                            showOnboardingFeatureTour = false
                        }
                    )
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack(alignment: .top) {
                // Global background is just system color now.
                // The user photo is handled *inside MainView* only.
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                // Horizontal pager: Community ← Main → Right
                pager
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
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
        MainView(isPageActive: activePage == .main)

    }

#if DEBUG
    @ViewBuilder
    private func debugView(for screen: BrainMailDebugLaunchScreen) -> some View {
        switch screen {
        case .main:
            NavigationStack {
                MainView(isPageActive: true)
            }
        case .community:
            NavigationStack {
                CommunityView()
            }
        case .settings:
            NavigationStack {
                RightPanelPlaceholderView()
            }
        }
    }
#endif

}

#if DEBUG
private enum BrainMailDebugLaunchScreen: String {
    case main
    case community
    case settings
}

private enum BrainMailDebugLaunchRoute {
    static var requestedScreen: BrainMailDebugLaunchScreen? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-BrainMailDebugScreen") else {
            return nil
        }

        let valueIndex = args.index(after: index)
        guard args.indices.contains(valueIndex) else {
            return nil
        }

        return BrainMailDebugLaunchScreen(rawValue: args[valueIndex])
    }
}
#endif
