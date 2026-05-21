// ============================================
// File: Views/Main/Components/TopBarActions.swift
// ============================================
import SwiftUI

struct TopBarActions: View {
    let count: Int
    let isOnline: Bool
    let isActive: Bool

    var onExport: () -> Void
    var onSendNow: () -> Void

    var body: some View {
        let hasSavedEntries = count > 0

        HStack(spacing: 18) {
            // Export requires a saved entry.
            Button(action: onExport) {
                Image(systemName: "envelope.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.blue)
            }
            .disabled(!isOnline || !hasSavedEntries)
            .opacity(!isOnline ? 0.35 : (!hasSavedEntries ? 0.35 : 1.0))

            // Send now requires a saved entry and an active SMS profile.
            Button(action: onSendNow) {
                Image(systemName: "bolt.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.blue)
            }
            .disabled(!isOnline || !hasSavedEntries || !isActive)
            .opacity(!isOnline ? 0.35 : ((!hasSavedEntries || !isActive) ? 0.35 : 1.0))
        }
    }
}
