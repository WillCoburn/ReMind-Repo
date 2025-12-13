// ============================
// File: Views/Onboarding/CodeEntryScreen.swift
// ============================
import SwiftUI

struct CodeEntryScreen: View {
    @Binding var code: String
    let phoneNumber: String

    let errorText: String
    let isVerifying: Bool

    let onBack: () -> Void
    let onResend: () -> Void
    let onVerify: () -> Void

    @StateObject private var keyboard = KeyboardObserver()

    var body: some View {
        GeometryReader { geo in
            let safeBottom = geo.safeAreaInsets.bottom
            let lift = max(0, keyboard.height - safeBottom)

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    CodeEntrySection(
                        code: $code,
                        phoneNumber: phoneNumber,
                        onEditNumber: onBack,
                        onResend: onResend
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, keyboard.isVisible ? 12 : 24)

                    Spacer(minLength: keyboard.isVisible ? 10 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(spacing: 12) {
                    if !errorText.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(errorText)
                                .font(.callout)
                                .foregroundColor(.red)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.35), lineWidth: 1)
                        )
                    }

                    Button(action: onVerify) {
                        ZStack {
                            Text(isVerifying ? "Verifying…" : "Verify Code")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .opacity(isVerifying ? 0 : 1)

                            if isVerifying {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(code.count == 6 ? Color.figmaBlue : Color.gray.opacity(0.35))
                        .cornerRadius(14)
                    }
                    .disabled(code.count < 6 || isVerifying)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16 + lift)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .animation(.easeInOut(duration: keyboard.animationContext.duration), value: keyboard.isVisible)
        }
    }
}
