// ============================
// File: Views/Sheets/ExportSheet.swift (PLACEHOLDER)
// ============================

import SwiftUI

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "envelope")
                    .font(.largeTitle)
                Text("Export coming soon")
                    .font(.headline)
                Text("Emailing a PDF of your affirmations will be added in a later build.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Export")
        }
    }
}
