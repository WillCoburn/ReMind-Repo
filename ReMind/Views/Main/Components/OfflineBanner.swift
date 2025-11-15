// ============================
// File: UI/Components/OfflineBanner.swift
// ============================
import SwiftUI

/// Center-screen offline popup. Appears when shown by the NetworkAwareModifier
/// and disappears automatically when connectivity is restored.
struct OfflineBanner: View {
    var body: some View {
        ZStack {
            // Dimmed backdrop that blocks taps
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            // Card
            VStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36, weight: .semibold))
                Text("You’re Offline")
                    .font(.headline)
                Text("Please reconnect to the internet to continue using ReMind.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                ProgressView("Waiting for connection…")
                    .padding(.top, 4)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: 360)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 12)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }
}
