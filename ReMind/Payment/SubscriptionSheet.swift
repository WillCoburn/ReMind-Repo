import SwiftUI
import RevenueCat
import RevenueCatUI

struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel
    @State private var restoreMessage: String?
    @State private var restoreMessageIsError = true
    @State private var restoreMessageClearTask: Task<Void, Never>?
    @State private var restoreDismissTask: Task<Void, Never>?
    @State private var restoreTimeoutTask: Task<Void, Never>?
    @State private var isRestoreInProgress = false

    var body: some View {
        PaywallView(displayCloseButton: true)
            .allowsHitTesting(!isRestoreInProgress)
            .onPurchaseCompleted { customerInfo in
                let revenueCat = RevenueCatManager.shared
                revenueCat.applyCustomerInfo(customerInfo)
                appVM.applyFreshRevenueCatCustomerInfo(customerInfo, reason: "paywallPurchaseCompleted")
                revenueCat.refreshEntitlementState(reason: "paywallPurchaseCompleted", force: true)
                appVM.refreshRevenueCatEntitlement(reason: "paywallPurchaseCompleted")

                if revenueCat.hasActiveProEntitlement(customerInfo) {
                    dismiss()
                } else {
                    setRestoreMessage("Purchase completed, but Pro is not active yet. Please try again.", isError: true)
                }
            }
            .onRestoreStarted {
                beginRestoreLoading()
            }
            .onRestoreCompleted { customerInfo in
                finishRestoreLoading()
                let revenueCat = RevenueCatManager.shared
                revenueCat.applyCustomerInfo(customerInfo)
                appVM.applyFreshRevenueCatCustomerInfo(customerInfo, reason: "paywallRestoreCompleted")
                revenueCat.refreshEntitlementState(reason: "paywallRestoreCompleted", force: true)
                appVM.refreshRevenueCatEntitlement(reason: "paywallRestoreCompleted")

                if revenueCat.hasActiveProEntitlement(customerInfo) {
                    setRestoreMessage("Purchases restored.", isError: false)
                    restoreDismissTask?.cancel()
                    restoreDismissTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 850_000_000)
                        guard !Task.isCancelled else { return }
                        dismiss()
                    }
                } else {
                    setRestoreMessage(revenueCat.noActiveSubscriptionRestoreMessage, isError: true)
                }
            }
            .onRestoreFailure { error in
                finishRestoreLoading()
                setRestoreMessage(RevenueCatManager.shared.restoreFailureMessage(from: error), isError: true)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
            .overlay(alignment: .bottom) {
                restoreStatusOverlay
            }
            .animation(.easeInOut(duration: 0.18), value: restoreMessage)
            .animation(.easeInOut(duration: 0.18), value: isRestoreInProgress)
            .onDisappear {
                restoreMessageClearTask?.cancel()
                restoreDismissTask?.cancel()
                restoreTimeoutTask?.cancel()
                restoreMessageClearTask = nil
                restoreDismissTask = nil
                restoreTimeoutTask = nil
                isRestoreInProgress = false
            }
    }

    @ViewBuilder
    private var restoreStatusOverlay: some View {
        if isRestoreInProgress {
            restoreStatusPill(
                message: "Restoring purchases...",
                isError: false,
                showsSpinner: true
            )
        } else if let restoreMessage {
            restoreStatusPill(
                message: restoreMessage,
                isError: restoreMessageIsError,
                showsSpinner: false
            )
        }
    }

    private func restoreStatusPill(
        message: String,
        isError: Bool,
        showsSpinner: Bool
    ) -> some View {
        HStack(spacing: 9) {
            if showsSpinner {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.figmaBlue.opacity(0.78))
                    .scaleEffect(0.82)
            }

            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isError ? Color.red.opacity(0.86) : Color.figmaBlue.opacity(0.82))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isError ? Color.red.opacity(0.18) : Color.figmaBlue.opacity(0.14),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .allowsHitTesting(false)
    }

    private func beginRestoreLoading() {
        restoreDismissTask?.cancel()
        restoreMessageClearTask?.cancel()
        restoreTimeoutTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) {
            restoreMessage = nil
            restoreMessageIsError = false
            isRestoreInProgress = true
        }
        restoreTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled, isRestoreInProgress else { return }
            finishRestoreLoading()
            setRestoreMessage("Restore is taking longer than expected. Please try again.", isError: true)
        }
    }

    private func finishRestoreLoading() {
        restoreTimeoutTask?.cancel()
        restoreTimeoutTask = nil
        guard isRestoreInProgress else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            isRestoreInProgress = false
        }
    }

    private func setRestoreMessage(_ message: String, isError: Bool) {
        restoreMessageClearTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) {
            restoreMessage = message
            restoreMessageIsError = isError
        }
        restoreMessageClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_800_000_000)
            guard restoreMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                restoreMessage = nil
            }
        }
    }
}
