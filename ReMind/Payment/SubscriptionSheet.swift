// ReMind/Payment/SubscriptionSheet.swift
import SwiftUI
import RevenueCatUI
import FirebaseAuth


struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel
    @ObservedObject private var revenueCat: RevenueCatManager = .shared
    @State private var detent: PresentationDetent = .large   // 👈 start expanded

    private var statusText: String {
        if appVM.isTrialActive { return "Subscription status: Trial" }
        if appVM.isEntitled { return "Subscription status: Subscribed" }
        return "Subscription status: Unsubscribed"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(statusText)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { _ in
                    print("🧪 purchase completed uid:", Auth.auth().currentUser?.uid ?? "nil")

                    // Force an immediate RC sync so Firestore reflects the purchase right away.
                    RevenueCatManager.shared.refreshEntitlementState()
                    //RevenueCatManager.shared.recomputeAndPersistActive()
                    dismiss()
                }
                .onRestoreCompleted { _ in dismiss() }
        }
        .padding()
        .presentationDetents([.large], selection: $detent) // only large
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }
}
