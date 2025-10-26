// ============================
// File: Views/Sheets/ExportSheet.swift
// ============================

import SwiftUI

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel

    @State private var isSending = false
    @State private var successUrl: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor) // <- FIX

                Text("Text a PDF of your history")
                    .font(.title3.weight(.semibold))

                Text("We’ll compile every entry you’ve written and text you a downloadable PDF using your saved phone number.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let successUrl {
                    VStack(spacing: 8) {
                        Label("Check your messages for a link that expires in a few hours.", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                        Text(successUrl)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                    }
                    .transition(.opacity)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task { await sendExport() }
                } label: {
                    HStack {
                        if isSending { ProgressView().tint(.white) }
                        Text(isSending ? "Preparing…" : "Text me my PDF")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending)

                Spacer()
            }
            .padding()
            .navigationTitle("Export history")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func sendExport() async {
        guard !isSending else { return }
        isSending = true
        errorMessage = nil
        successUrl = nil

        let result = await appVM.sendHistoryPdf()

        isSending = false

        if result.success {
            successUrl = result.mediaUrl
        } else {
            errorMessage = result.errorMessage ?? "Something went wrong. Please try again."
        }
    }
}
