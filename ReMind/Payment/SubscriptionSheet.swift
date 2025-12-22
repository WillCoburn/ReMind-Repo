import SwiftUI
import RevenueCatUI

struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in dismiss() }
            .onRestoreCompleted { _ in dismiss() }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
    }
}
