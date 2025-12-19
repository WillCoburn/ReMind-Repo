// ReMind/Payment/SubscriptionSheet.swift
import SwiftUI
import RevenueCatUI
import FirebaseAuth


struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var detent: PresentationDetent = .large   // 👈 start expanded

    var body: some View {
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in
                print("🧪 purchase completed uid:", Auth.auth().currentUser?.uid ?? "nil")
                
                // Force an immediate RC sync so Firestore reflects the purchase right away.
                RevenueCatManager.shared.refreshEntitlementState()
                RevenueCatManager.shared.recomputeAndPersistActive()
                dismiss()
            }
            .onRestoreCompleted { _ in dismiss() }
            .presentationDetents([.large], selection: $detent) // only large
            // If you want medium available but still start large:
            // .presentationDetents([.medium, .large], selection: $detent)
            // .onAppear { detent = .large }
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
    }
}
