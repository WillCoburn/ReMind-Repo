// ReMind/Payment/TrialExpiryBanner.swift
import SwiftUI

struct TrialExpiryBanner: View {
    var onSubscribe: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Your 30-day free trial has ended.")
                .font(.subheadline).bold()
            Text("Start your subscription to resume reminders.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Start Subscription") { onSubscribe() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.yellow.opacity(0.18))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
