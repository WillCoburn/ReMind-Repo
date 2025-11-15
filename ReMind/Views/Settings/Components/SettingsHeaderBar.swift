// ======================================================
// File: Views/Settings/Components/SettingsHeaderBar.swift
// ======================================================
import SwiftUI

struct SettingsHeaderBar: View {
    var title: String
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
