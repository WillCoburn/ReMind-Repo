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

    var body: some View {
        ZStack {
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
                .padding(.top, 24)
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
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    private var topContent: some View {
        VStack(spacing: 10) {
            Image("FullLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 110)

            Text("Enter your phone number to continue.")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
