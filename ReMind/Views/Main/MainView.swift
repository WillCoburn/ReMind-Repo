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
            ZStack(alignment: .bottom) {
                backgroundLayer
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Image("FullLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 300, height: 120)   // tune as needed
                            .padding(.top, 4)
                        
                        if showSuccessMessage {
                            Text("✅ Successfully stored!")
                                .font(.footnote)
                                .foregroundColor(.green)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(.easeInOut(duration: 0.3), value: showSuccessMessage)
                        }
                        
                        EntryComposer(
                            text: $input,
                            isSubmitting: $isSubmitting,
                            isDisabled: buttonDisabled,
                            isEntryFieldFocused: _isEntryFieldFocused,
                            onSubmit: { await sendEntry() }
                        )
                        
                        HintBadge(count: count, goal: goal)
                        
                        if !active {
                            TrialBanner { showPaywall = true }
                                .padding(.top, 8)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 180)
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
                
                bottomActionBar(active: active, count: count)
            }
            // 👇 This makes the whole screen (including background) extend under the status bar + home indicator
            .ignoresSafeArea()
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
                .tint(.figmaBlue)
        }
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
                Color.white
                    .overlay(Color.blue.opacity(0.04))
                    .frame(
                        width: max(proxy.size.width, 1),
                        height: max(proxy.size.height, 1)
                    )
                    .ignoresSafeArea()
            }
        }
    }
    
    private func bottomActionBar(active: Bool, count: Int) -> some View {
        let canExport = net.isConnected && count >= goal
        let canSendNow = net.isConnected && count >= goal && active
        
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                bottomActionButton(
                    title: "Send one now",
                    systemImage: "envelope",
                    isEnabled: canSendNow,
                    action: handleSendNowTap
                )
                bottomActionButton(
                    title: "Export PDF",
                    systemImage: "doc.richtext",
                    isEnabled: canExport,
                    action: handleExportTap
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(colors: [Color.white.opacity(0.92), Color.white.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                .blur(radius: 12)
                .ignoresSafeArea(edges: .bottom)
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    private func bottomActionButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                Spacer(minLength: 8)
                Image(systemName: systemImage)
                    .font(.headline)
            }
            .foregroundColor(.figmaBlue)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.figmaBlue, lineWidth: 1)
            )
            .cornerRadius(12)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .disabled(!isEnabled)
    }d
    
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


