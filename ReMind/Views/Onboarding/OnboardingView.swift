// ============================
// File: Views/Onboarding/OnboardingView.swift
// ============================
import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFunctions

struct OnboardingView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var net: NetworkMonitor   // 👈 network state

    enum Step { case enterPhone, enterCode }
    @State private var step: Step = .enterPhone

    // Phone entry (store DIGITS ONLY; format only for display)
    @State private var phoneDigits: String = ""        // "5551234567"
    @State private var showErrorBorder = false
    @State private var errorText: String = ""
    @State private var hasConsented = false

    // Code entry
    @State private var verificationID: String?
    @State private var code: String = ""

    // Spinners
    @State private var isSending = false
    @State private var isVerifying = false

    // ✅ Firebase Functions client
    private let functions = Functions.functions(region: "us-central1")

    private var isValidPhone: Bool { phoneDigits.count == 10 }
    private var canContinueBase: Bool { isValidPhone && hasConsented }
    private var canContinueOnline: Bool { canContinueBase && net.isConnected } // 👈 disable when offline

    private let consentMessage =
    """
    By tapping Agree, you consent to receive reminder text messages from ReMind to the phone number you provide. Message & data rates may apply. Reply STOP to opt out, or HELP for support.
    """

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            Text("ReMind")
                .font(.system(size: 44, weight: .bold))

            Text("Celebrate when it's all clear, and prepare for when it's not.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Group {
                switch step {
                case .enterPhone:
                    PhoneEntrySection(
                        phoneDigits: $phoneDigits,
                        showErrorBorder: $showErrorBorder,
                        errorText: $errorText,
                        isValidPhone: isValidPhone
                    )

                case .enterCode:
                    CodeEntrySection(
                        code: $code,
                        isVerifying: isVerifying,
                        onEditNumber: {
                            step = .enterPhone
                            errorText = ""
                            code = ""
                        },
                        onVerify: {
                            Task { await verifyCode() }
                        }
                    )
                }
            }

            if !errorText.isEmpty {
                Text(errorText)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .transition(.opacity
                        .combined(with: .move(edge: .top)))
            }

            Spacer()

            if step == .enterPhone {
                ConsentAndAgreeBottom(
                    hasConsented: $hasConsented,
                    consentMessage: consentMessage,
                    canContinue: canContinueOnline, // 👈 pass online-aware flag
                    isSending: isSending,
                    onAgreeAndContinue: {
                        Task { await sendCode() }
                    }
                )
            }
        }
        
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .ignoresSafeArea()
        
        .padding(.horizontal)
        .animation(.default, value: step)
        .animation(.default, value: errorText)
        .animation(.easeInOut, value: isValidPhone)
        .networkAware() // 👈 center popup while offline
        .onChange(of: net.isConnected) { value in
            print("🔄 net.isConnected ->", value)
        }
    }

    // MARK: - Actions

    private func sendCode() async {
        guard canContinueBase else { return }
        guard net.isConnected else {                 // 👈 offline guard
            errorText = "No internet connection. Please reconnect and try again."
            return
        }

        errorText = ""
        isSending = true
        defer { isSending = false }

        let e164 = "+1\(phoneDigits)"

        do {
            let verID = try await PhoneAuthProvider.provider().verifyPhoneNumber(e164, uiDelegate: nil)
            self.verificationID = verID
            self.step = .enterCode
        } catch {
            self.errorText = "Failed to send code. Please try again."
            print("verifyPhone error:", error)
        }
    }

    private func verifyCode() async {
        guard let verID = verificationID else { return }
        guard net.isConnected else {                 // 👈 offline guard
            errorText = "No internet connection. Please reconnect and try again."
            return
        }

        errorText = ""
        isVerifying = true
        defer { isVerifying = false }

        let credential = PhoneAuthProvider.provider()
            .credential(withVerificationID: verID, verificationCode: code)

        do {
            _ = try await Auth.auth().signIn(with: credential)
            await appVM.setPhoneProfileAndLoad(phoneDigits)

            // ✅ Trigger welcome message after onboarding completes
            do {
                let result = try await functions.httpsCallable("triggerWelcome").call([:])
                print("✅ triggerWelcome result:", result.data)
            } catch {
                print("❌ triggerWelcome error:", error.localizedDescription)
            }

        } catch {
            self.errorText = "Invalid or expired code. Please try again."
            print("signIn error:", error)
        }
    }
}
