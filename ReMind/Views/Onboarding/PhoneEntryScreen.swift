// ============================
// File: Views/Onboarding/PhoneEntryScreen.swift
// ============================
import SwiftUI

struct PhoneEntryScreen: View {
    @Binding var phoneDigits: String
    @Binding var showErrorBorder: Bool
    @Binding var errorText: String
    @Binding var hasConsented: Bool

    let isSending: Bool
    let isValidPhone: Bool
    let consentMessage: String
    let canContinue: Bool
    let onContinue: () -> Void

    @StateObject private var keyboard = KeyboardObserver()

    var body: some View {
        GeometryReader { geo in
            let lift = keyboard.overlap(in: geo)

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    topContent
                        .padding(.top, 36)
                        .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Phone")
                            .font(.headline)

                        PhoneEntrySection(
                            phoneDigits: $phoneDigits,
                            showErrorBorder: $showErrorBorder,
                            errorText: $errorText,
                            isValidPhone: isValidPhone
                        )

                        if !errorText.isEmpty {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, keyboard.isVisible ? 14 : 24)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                ConsentAndAgreeBottom(
                    hasConsented: $hasConsented,
                    consentMessage: consentMessage,
                    canContinue: canContinue,
                    isSending: isSending,
                    onAgreeAndContinue: onContinue
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 16 + lift)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(.keyboard, edges: .all)
            .animation(.easeInOut(duration: keyboard.animationContext.duration), value: keyboard.isVisible)
        }
    }

    private var topContent: some View {
        VStack(spacing: keyboard.isVisible ? 6 : 10) {
            Image("FullLogo")
                .resizable()
                .scaledToFit()
                .frame(width: keyboard.isVisible ? 170 : 220, height: keyboard.isVisible ? 72 : 110)
                .animation(.easeInOut(duration: 0.2), value: keyboard.isVisible)

            if !keyboard.isVisible {
                Text("Enter your phone number to continue.")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
