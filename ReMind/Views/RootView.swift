// =====================
// File: Views/RootView.swift
// =====================
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appVM: AppViewModel
    
    // Which horizontal page we’re on
    private enum Page: Hashable { case community, main, right }
    @State private var activePage: Page = .main
    
    
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
                    
                    
                    // Feature tour overlay (only on main page)
                    if appVM.showFeatureTour, activePage == .main {
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
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    @ViewBuilder
    private var mainPage: some View {
        MainView()
        
    }
    
}
