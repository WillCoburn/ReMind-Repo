import SwiftUI
import RevenueCat
import RevenueCatUI

struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel
    @State private var restoreMessage: String?
    @State private var restoreMessageClearTask: Task<Void, Never>?

    var body: some View {
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { customerInfo in
                let revenueCat = RevenueCatManager.shared
                revenueCat.applyCustomerInfo(customerInfo)
                appVM.applyFreshRevenueCatCustomerInfo(customerInfo, reason: "paywallPurchaseCompleted")
                revenueCat.refreshEntitlementState(reason: "paywallPurchaseCompleted", force: true)
                appVM.refreshRevenueCatEntitlement(reason: "paywallPurchaseCompleted")

                if revenueCat.hasActiveProEntitlement(customerInfo) {
                    dismiss()
                } else {
                    setRestoreMessage("Purchase completed, but Pro is not active yet. Please try again.")
                }
            }
            .onRestoreCompleted { customerInfo in
                let revenueCat = RevenueCatManager.shared
                revenueCat.applyCustomerInfo(customerInfo)
                appVM.applyFreshRevenueCatCustomerInfo(customerInfo, reason: "paywallRestoreCompleted")
                revenueCat.refreshEntitlementState(reason: "paywallRestoreCompleted", force: true)
                appVM.refreshRevenueCatEntitlement(reason: "paywallRestoreCompleted")

                if revenueCat.hasActiveProEntitlement(customerInfo) {
                    dismiss()
                } else {
                    setRestoreMessage(revenueCat.noActiveSubscriptionRestoreMessage)
                }
            }
            .onRestoreFailure { error in
                setRestoreMessage(RevenueCatManager.shared.restoreFailureMessage(from: error))
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
            .overlay(alignment: .bottom) {
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.red.opacity(0.86))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.red.opacity(0.18), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 22)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: restoreMessage)
            .onDisappear {
                restoreMessageClearTask?.cancel()
                restoreMessageClearTask = nil
            }
    }

    private func setRestoreMessage(_ message: String) {
        restoreMessageClearTask?.cancel()
        restoreMessage = message
        restoreMessageClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_800_000_000)
            guard restoreMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                restoreMessage = nil
            }
        }
    }
}
