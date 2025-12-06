// ============================
// File: Views/Onboarding/ConsentAndAgreeBottom.swift
// ============================
import SwiftUI

struct ConsentAndAgreeBottom: View {
    @Binding var hasConsented: Bool
    let consentMessage: String
    let canContinue: Bool
    let isSending: Bool
    let onAgreeAndContinue: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16) {

            // MARK: - Terms & Privacy links (underlined + figmaBlue)
            HStack(spacing: 4) {
                Link(destination: URL(string: "https://re-mind-app.github.io/remind-site/terms.html")!) {
                    Text("Terms & Conditions")
                        .font(.footnote)
                        .foregroundColor(.figmaBlue)
                        .underline()
                }

                Text("and")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Link(destination: URL(string: "https://re-mind-app.github.io/remind-site/privacy.html")!) {
                    Text("Privacy Policy")
                        .font(.footnote)
                        .foregroundColor(.figmaBlue)
                        .underline()
                }
            }
            .multilineTextAlignment(.center)

            // MARK: - Checkbox + consent message
            HStack(alignment: .top, spacing: 10) {
                Button {
                    hasConsented.toggle()
                } label: {
                    Image(systemName: hasConsented ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(hasConsented ? .figmaBlue : .secondary)
                }
                .buttonStyle(.plain)

                Text(consentMessage)
                    .font(.caption2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.black)   // 👈 explicitly black
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // MARK: - Primary button
            Button {
                onAgreeAndContinue()
            } label: {
                ZStack {
                    Text(isSending ? "Sending…" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .opacity(isSending ? 0 : 1)

                    if isSending {
                        ProgressView()
                            .padding(.vertical)
                    }
                }
                .background(canContinue ? Color.figmaBlue : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(!canContinue || isSending)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
