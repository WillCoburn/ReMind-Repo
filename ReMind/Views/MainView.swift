// ======================
// File: Views/MainView.swift
// ======================
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var net: NetworkMonitor   // 👈 network state

    @State private var input: String = ""
    @State private var showExportSheet = false
    @State private var showSuccessMessage = false
    @State private var showPaywall = false
    @State private var isSubmitting = false
    

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

            HStack(alignment: .center, spacing: 12) {
                TextField("Type an entry…", text: $input, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )

                Button {
                    Task { await sendEntry() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(buttonDisabled)
                .opacity(buttonDisabled ? 0.4 : 1.0)
                .accessibilityLabel("Submit entry")
                .accessibilityHint(
                    !net.isConnected
                    ? "Unavailable while offline."
                    : (!active ? "Start a subscription to continue after your free trial."
                       : (inputIsEmpty ? "Type something to enable." : "Saves your entry."))
                )
            }
            .padding(.horizontal)

            HintBadge(count: count, goal: goal)
                .padding(.horizontal)

            Spacer(minLength: 16)
        }
        .navigationTitle("ReMind")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {

                // 📩 Export — requires online, >=10, and NOT opted-out
                Button {
                    Task {
                        guard net.isConnected else {
                            presentOfflineAlert()
                            return
                        }
                        if count < goal {
                            presentLockedAlert(feature: "Export PDF")
                            return
                        }
                        let freshOptOut = await appVM.reloadSmsOptOut()
                        if freshOptOut {
                            presentOptOutAlert()
                            return
                        }
                        showExportSheet = true
                    }
                } label: {
                    Image(systemName: "envelope.fill")
                        .font(.title3.weight(.semibold))
                }
                .disabled(!net.isConnected || count < goal)
                .opacity(!net.isConnected ? 0.35 : (count < goal ? 0.35 : 1.0))

                // ⚡ Send now — requires online, >=10, NOT opted-out, AND active
                Button {
                    Task {
                        guard net.isConnected else {
                            presentOfflineAlert()
                            return
                        }
                        if count < goal {
                            presentLockedAlert(feature: "Send One Now")
                            return
                        }
                        let freshOptOut = await appVM.reloadSmsOptOut()
                        if freshOptOut {
                            presentOptOutAlert()
                            return
                        }
                        guard active else {
                            alertTitle = "Subscribe to Continue"
                            alertMessage = "Your free trial has ended. Start a subscription to send reminders."
                            showAlert = true
                            return
                        }
                        let ok = await appVM.sendOneNow()
                        if ok { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
                    }
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.title3.weight(.semibold))
                }
                .disabled(!net.isConnected || count < goal || !active)
                .opacity(!net.isConnected ? 0.35 : ((count < goal || !active) ? 0.35 : 1.0))
            }
        }
        .sheet(isPresented: $showExportSheet) { ExportSheet() }
        .sheet(isPresented: $showPaywall) { SubscriptionSheet() }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(alertMessage) }
        .overlay(alignment: .center) {
            if !net.isConnected {
                OfflineBanner()
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .allowsHitTesting(net.isConnected)
        .onChange(of: net.isConnected) { value in
            print("🔄 net.isConnected (MainView) ->", value)
        }
        .onAppear {
            RevenueCatManager.shared.recomputeAndPersistActive()
        }
    }

    // MARK: - Actions
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
        withAnimation(.easeInOut(duration: 0.2)) { showSuccessMessage = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) { showSuccessMessage = false }
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

// Inline banner so this file compiles even if you don’t add Payment/TrialExpiryBanner.swift
private struct TrialBanner: View {
    var onTap: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            Text("Your 30-day free trial has ended.")
                .font(.subheadline).bold()
            Text("Start your subscription to resume reminders.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Start Subscription") { onTap() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.yellow.opacity(0.18))
        .cornerRadius(12)
    }
}
