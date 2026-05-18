import SwiftUI
import RevenueCatUI

struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in
                RevenueCatManager.shared.refreshEntitlementState(reason: "paywallPurchaseCompleted", force: true)
                dismiss()
            }
            .onRestoreCompleted { _ in
                RevenueCatManager.shared.refreshEntitlementState(reason: "paywallRestoreCompleted", force: true)
                dismiss()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
    }
}
