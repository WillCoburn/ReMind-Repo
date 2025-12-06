// ======================================================
// File: Views/Settings/Components/SettingsHeaderBar.swift
// ======================================================
import SwiftUI

struct SettingsHeaderBar: View {
    var title: String
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top grab handle
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Title + close button
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)   // 👈 make header title clearly black

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
        .frame(maxWidth: .infinity)
        .background(
            // 👇 Match your settings background instead of system dark gray
            ZStack {
                Color.white
                Color.figmaBlue.opacity(0.08)
            }
            .ignoresSafeArea(edges: .top)
        )
    }
}
