// ============================
// File: UI/Modifiers/NetworkAwareModifier.swift
// ============================
import SwiftUI

struct NetworkAwareModifier: ViewModifier {
    @EnvironmentObject private var net: NetworkMonitor

    func body(content: Content) -> some View {
        ZStack {
            // Disable interaction with underlying content while offline
            content
                .allowsHitTesting(net.isConnected)

            if !net.isConnected {
                OfflineBanner()
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: net.isConnected)
    }
}

extension View {
    func networkAware() -> some View { modifier(NetworkAwareModifier()) }
}
