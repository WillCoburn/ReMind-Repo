// ============================
// File: Views/Onboarding/CodeEntrySection.swift
// ============================
import SwiftUI

struct CodeEntrySection: View {
    @Binding var code: String
    let isVerifying: Bool
    let onEditNumber: () -> Void
    let onVerify: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enter Verification Code")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("123456", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

            HStack {
                Button("Edit number") {
                    onEditNumber()
                }

                Spacer()

                Button {
                    onVerify()
                } label: {
                    ZStack {
                        Text(isVerifying ? "Verifying…" : "Verify & Continue")
                            .bold()
                            .opacity(isVerifying ? 0 : 1)
                        if isVerifying { ProgressView() }
                    }
                }
                .disabled(code.count < 6 || isVerifying)
            }
        }
    }
}
