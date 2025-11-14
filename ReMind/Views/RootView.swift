// =====================
// File: Views/RootView.swift
// =====================
import SwiftUI
import PhotosUI

struct RootView: View {
    @EnvironmentObject private var appVM: AppViewModel

    // Settings UI state
    @State private var showSettings = false

    // Persisted settings (simple local storage for now)
    @AppStorage("remindersPerWeek") private var remindersPerWeek: Double = 7.0 // 1...20
    @AppStorage("tzIdentifier")    private var tzIdentifier: String = TimeZone.current.identifier
    @AppStorage("quietStartHour")  private var quietStartHour: Double = 9     // 0...23
    @AppStorage("quietEndHour")    private var quietEndHour: Double = 22      // 0...23

    // Background image (stored as Base64 string for portability)
    @AppStorage("bgImageBase64")   private var bgImageBase64: String = ""

    var body: some View {
        Group {
            if !appVM.hasLoadedInitialProfile {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appVM.shouldShowOnboarding {
                OnboardingView()
            } else {
                NavigationView {
                    ZStack(alignment: .top) {
                        // Background layer (custom image or system background color)
                        backgroundLayer
                            .ignoresSafeArea()

                        // Your main content
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
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Log Out") { appVM.logout() }
                                }
                                // Settings button (top-right)
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                            showSettings.toggle()
                                        }
                                    } label: {
                                        Image(systemName: "gearshape.fill")
                                            .imageScale(.large)
                                            .accessibilityLabel("Settings")
                                    }
                                }
                            }

                        // Slide-down settings panel overlay
                        if showSettings {

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

                        if appVM.showFeatureTour {
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
        }
        // Animate when the onboarding gate flips
        .animation(.default, value: appVM.shouldShowOnboarding)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appVM.featureTourStep)
        .animation(.easeInOut(duration: 0.25), value: appVM.showFeatureTour)
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

    // MARK: - Background renderer

    @ViewBuilder
    private var backgroundLayer: some View {
        GeometryReader { proxy in
            if let uiImage = decodeBase64ToImage(bgImageBase64) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    // Clamp to the actual container bounds to avoid oversized ideal sizes
                    .frame(width: max(proxy.size.width, 1),
                           height: max(proxy.size.height, 1))
                    .clipped()
                    .overlay(.black.opacity(0.15)) // subtle contrast for readability
            } else {
                Color(UIColor.systemBackground)
                    .frame(width: max(proxy.size.width, 1),
                           height: max(proxy.size.height, 1))
            }
        }
    }

    private func decodeBase64ToImage(_ base64: String) -> UIImage? {
        guard !base64.isEmpty, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}
