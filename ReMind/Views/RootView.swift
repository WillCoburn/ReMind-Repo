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
    @AppStorage("remindersPerDay") private var remindersPerDay: Double = 1.0 // 0.1...5
    @AppStorage("tzIdentifier")    private var tzIdentifier: String = TimeZone.current.identifier
    @AppStorage("quietStartHour")  private var quietStartHour: Double = 9     // 0...23
    @AppStorage("quietEndHour")    private var quietEndHour: Double = 22      // 0...23

    // Background image (stored as Base64 string for portability)
    @AppStorage("bgImageBase64")   private var bgImageBase64: String = ""

    var body: some View {
        Group {
            if appVM.user != nil {
                NavigationView {
                    ZStack(alignment: .top) {
                        // Background layer (custom image or system background color)
                        backgroundLayer
                            .ignoresSafeArea()

                        // Your main content
                        MainView()
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
                            Color.black.opacity(0.25)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                        showSettings = false
                                    }
                                    // Persist settings to Firestore so backend can schedule sends
                                    UserSettingsSync.pushAndApply { err in
                                        print("pushAndApply ->", err?.localizedDescription ?? "OK")
                                    }

                                }

                            UserSettingsPanel(
                                remindersPerDay: $remindersPerDay,
                                tzIdentifier: $tzIdentifier,
                                quietStartHour: $quietStartHour,
                                quietEndHour: $quietEndHour,
                                bgImageBase64: $bgImageBase64,
                                onClose: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                        showSettings = false
                                    }
                                    // NEW: push settings to Firestore so backend can schedule sends
                                    UserSettingsSync.pushAndApply { err in
                                        print("pushAndApply ->", err?.localizedDescription ?? "OK")
                                    }

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
            } else {
                OnboardingView()
            }
        }
        // animate when user logs in/out
        .animation(.default, value: appVM.user != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appVM.featureTourStep)
        .animation(.easeInOut(duration: 0.25), value: appVM.showFeatureTour)
    }

    // MARK: - Background renderer

    @ViewBuilder
    private var backgroundLayer: some View {
        GeometryReader { proxy in
                    if let uiImage = decodeBase64ToImage(bgImageBase64) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            // GeometryReader gives us the actual container bounds, so we can
                            // pin the rendered bitmap to the NavigationView's real size instead
                            // of letting the photo's native pixel dimensions define an "ideal"
                            // width/height. Without this clamp, a panoramic image reports a
                            // multi-thousand point ideal width, the navigation stack expands to
                            // satisfy it, and MainView's entry bubble slides outside the
                            // visible viewport.
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
