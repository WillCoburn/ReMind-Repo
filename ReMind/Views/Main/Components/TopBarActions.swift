// ============================================
// File: Views/Main/Components/TopBarActions.swift
// ============================================
import SwiftUI

struct TopBarActions: View {
    let count: Int
    let goal: Int
    let isOnline: Bool
    let isActive: Bool

    var onExport: () -> Void
    var onSendNow: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            // 📩 Export — requires online, >=goal
            Button(action: onExport) {
                Image(systemName: "envelope.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.paletteTealGreen)
            }
            .disabled(!isOnline || count < goal)
            .opacity(!isOnline ? 0.35 : (count < goal ? 0.35 : 1.0))

            // ⚡ Send now — requires online, >=goal, AND active
            Button(action: onSendNow) {
                Image(systemName: "bolt.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.paletteTealGreen)
            }
            .disabled(!isOnline || count < goal || !isActive)
            .opacity(!isOnline ? 0.35 : ((count < goal || !isActive) ? 0.35 : 1.0))
        }
    }
}
