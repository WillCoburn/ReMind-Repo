// ======================
// File: Views/Main/MainView.swift
// ======================
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var net: NetworkMonitor   // 👈 network state

    // User-selected background image (Base64)
    @AppStorage("bgImageBase64") private var bgImageBase64: String = ""
    
    @State private var input: String = ""
    @State private var showExportSheet = false
    @State private var showSendNowSheet = false
    @State private var showSuccessMessage = false
    @State private var showPaywall = false
    @State private var isSubmitting = false
    @FocusState private var isEntryFieldFocused: Bool

    // Alerts
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let goal: Int = 5

    private func isActive(trialEndsAt: Date?) -> Bool {
        let entitled = RevenueCatManager.shared.entitlementActive
        let onTrial = trialEndsAt.map { Date() < $0 } ?? false
        return entitled || onTrial
    }

    var body: some View {
        let count = appVM.entries.count
        let active = isActive(trialEndsAt: appVM.user?.trialEndsAt)
        let inputIsEmpty = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let buttonDisabled = isSubmitting || inputIsEmpty || !net.isConnected || !active

        ZStack {
            Color.paletteIvory
                .ignoresSafeArea()

            // 🔹 Background now handled *here* so it only affects MainView.
            backgroundLayer

            VStack(spacing: 20) {
                Spacer(minLength: 32)

                if !active {
                    TrialBanner { showPaywall = true }
                        .padding(.horizontal)
                }

                if showSuccessMessage {
                    Text("✅ Successfully stored!")
                        .font(.footnote)
                        .foregroundColor(.green)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.3), value: showSuccessMessage)
                }

                // Composer row
                EntryComposer(
                    text: $input,
                    isSubmitting: $isSubmitting,
                    isDisabled: buttonDisabled,
                    isEntryFieldFocused: _isEntryFieldFocused,
                    onSubmit: { await sendEntry() }
                )
                .padding(.horizontal)

                HintBadge(count: count, goal: goal)
                    .padding(.horizontal)

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard isEntryFieldFocused else { return }
                    isEntryFieldFocused = false
                    hideKeyboard()
                },
                including: .gesture
            )
            .overlay(alignment: .center) {
                if !net.isConnected {
                    OfflineBanner()
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .allowsHitTesting(net.isConnected)
        }
        // 👇 This makes the whole screen (including background) extend under the status bar + home indicator
        .ignoresSafeArea()
        .navigationTitle("ReMind")
        .toolbar {
            // Keyboard toolbar
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    isEntryFieldFocused = false
                    hideKeyboard()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3)
                }
                .accessibilityLabel("Dismiss keyboard")
            }

            // Top right actions
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                TopBarActions(
                    count: appVM.entries.count,
                    goal: goal,
                    isOnline: net.isConnected,
                    isActive: active,
                    onExport: { handleExportTap() },
                    onSendNow: { handleSendNowTap() }
                )
            }
        }
        .sheet(isPresented: $showExportSheet) { ExportSheet() }
        .sheet(isPresented: $showSendNowSheet) { SendNowSheet() }
        .sheet(isPresented: $showPaywall) { SubscriptionSheet() }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(alertMessage) }
        .onChange(of: net.isConnected) { value in
            print("🔄 net.isConnected (MainView) ->", value)
        }
        .onAppear {
            RevenueCatManager.shared.recomputeAndPersistActive()
        }
        .tint(.blue)
    }

    // MARK: - Background just for MainView

    @ViewBuilder
    private var backgroundLayer: some View {
        GeometryReader { proxy in
            if let uiImage = decodeBase64ToImage(bgImageBase64) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: max(proxy.size.width, 1),
                        height: max(proxy.size.height, 1)
                    )
                    .clipped()
                    .overlay(Color.black.opacity(0.15)) // subtle contrast for readability
                    .ignoresSafeArea()
            } else {
                Color.paletteIvory
                    .frame(
                        width: max(proxy.size.width, 1),
                        height: max(proxy.size.height, 1)
                    )
                    .ignoresSafeArea()
            }
        }
    }

    private func decodeBase64ToImage(_ base64: String) -> UIImage? {
        guard !base64.isEmpty, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Actions

    @MainActor
    private func sendEntry() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        guard net.isConnected else {
            presentOfflineAlert()
            return
        }

        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        await appVM.submit(text: text)
        input = ""
        isEntryFieldFocused = false
        hideKeyboard()

        withAnimation(.easeInOut(duration: 0.2)) { showSuccessMessage = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) { showSuccessMessage = false }
        }
    }

    private func handleExportTap() {
        let count = appVM.entries.count
        guard net.isConnected else { presentOfflineAlert(); return }
        if count < goal { presentLockedAlert(feature: "Export PDF"); return }
        Task {
            let freshOptOut = await appVM.reloadSmsOptOut()
            if freshOptOut { presentOptOutAlert(); return }
            showExportSheet = true
        }
    }

    private func handleSendNowTap() {
        let count = appVM.entries.count
        let active = isActive(trialEndsAt: appVM.user?.trialEndsAt)

        guard net.isConnected else { presentOfflineAlert(); return }
        if count < goal { presentLockedAlert(feature: "Send One Now"); return }
        Task {
            let freshOptOut = await appVM.reloadSmsOptOut()
            if freshOptOut { presentOptOutAlert(); return }
            guard active else {
                alertTitle = "Subscribe to Continue"
                alertMessage = "Your free trial has ended. Start a subscription to send reminders."
                showAlert = true
                return
            }
            showSendNowSheet = true
        }
    }

    // MARK: - Alerts

    private func presentLockedAlert(feature: String) {
        alertTitle = "Keep going!"
        alertMessage = "You need at least \(goal) entries to use “\(feature)”. Add more entries to unlock this feature."
        showAlert = true
    }

    private func presentOptOutAlert() {
        alertTitle = "SMS Sending Is Blocked"
        alertMessage =
        """
        It looks like you’ve opted out of SMS for this number, so texts can’t be delivered.

        To re-enable messages, reply START or UNSTOP to the last ReMind text. After that, try again.
        """
        showAlert = true
    }

    private func presentOfflineAlert() {
        alertTitle = "No Internet Connection"
        alertMessage = "Please reconnect to the internet to use this feature."
        showAlert = true
    }
}


