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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    hasConsented.toggle()
                } label: {
                    Image(systemName: hasConsented ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)

                Text(consentMessage)
                    .font(.caption2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.black)
            }

            Button {
                onAgreeAndContinue()
            } label: {
                ZStack {
                    Text(isSending
                         ? "Sending…"
                         : (canContinue ? "Agree & Continue" : "Agree to Continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .opacity(isSending ? 0 : 1)
                    if isSending { ProgressView().padding(.vertical) }
                }
                .background(canContinue ? Color.black : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(!canContinue || isSending)

            HStack {
                Link("Privacy Policy",
                     destination: URL(string: "https://willcoburn.github.io/remind-site/privacy.html")!)
                Spacer()
                Link("Terms of Service",
                     destination: URL(string: "https://willcoburn.github.io/remind-site/terms.html")!)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
