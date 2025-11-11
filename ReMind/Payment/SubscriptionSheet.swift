// ReMind/Payment/SubscriptionSheet.swift
import SwiftUI
import RevenueCatUI

/// A self-contained sheet that displays the RC paywall and dismisses on success/restore.
struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            // Optional note to align with your in-app (non-Apple) trial messaging
            Text("After your 30-day free period, subscribe for $0.99/month. Cancel anytime.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Load the current/remote offering automatically (no optional argument)
            PaywallView()
                .onPurchaseCompleted { _ in dismiss() }
                .onRestoreCompleted { _ in dismiss() }
        }
        .presentationDetents([.medium, .large])
    }
}
