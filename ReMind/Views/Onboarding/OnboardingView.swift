// ============================
// File: Views/Onboarding/OnboardingView.swift
// ============================
import SwiftUI
import FirebaseAuth
import FirebaseFunctions

struct OnboardingView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var net: NetworkMonitor

    enum Step { case enterPhone, enterCode }
    @State private var step: Step = .enterPhone

    // Shared state
    @State private var phoneDigits: String = ""
    @State private var hasConsented = false
    @State private var showErrorBorder = false
    @State private var errorText: String = ""

    @State private var verificationID: String?
    @State private var code: String = ""

    @State private var isSending = false
    @State private var isVerifying = false
    
    // Track whether we're moving forward (entering code) or backward (editing phone)
      @State private var isAdvancing = true

    private let functions = Functions.functions(region: "us-central1")

    private var isValidPhone: Bool { phoneDigits.count == 10 }
    private var canContinueBase: Bool { isValidPhone && hasConsented }
    private var canContinueOnline: Bool { canContinueBase && net.isConnected }

    private var formattedPhoneDisplay: String {
        let formatted = PhoneField.Coordinator.format(phoneDigits)
        let base = formatted.isEmpty ? phoneDigits : formatted
        return "+1 \(base)"
    }
    
    private var forwardTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading))
    }

    private var backwardTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .leading),
                    removal: .move(edge: .trailing))
    }

    private let consentMessage = "By tapping 'Continue', you consent to receive reminder text messages from ReMind."

    var body: some View {
        ZStack {
            Image("MainBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            switch step {
            case .enterPhone:
                PhoneEntryScreen(
                    phoneDigits: $phoneDigits,
                    showErrorBorder: $showErrorBorder,
                    errorText: $errorText,
                    hasConsented: $hasConsented,
                    isSending: isSending,
                    isValidPhone: isValidPhone,
                    consentMessage: consentMessage,
                    canContinue: canContinueOnline,
                    onContinue: { Task { await sendCode() } }
                )
                .transition(isAdvancing ? forwardTransition : backwardTransition)

            case .enterCode:
                CodeEntryScreen(
                    code: $code,
                    phoneNumber: formattedPhoneDisplay,
                    errorText: errorText,
                    isVerifying: isVerifying,
                    onBack: {
                        isAdvancing = false
                        step = .enterPhone
                        errorText = ""
                        code = ""
                    },
                    onResend: { Task { await sendCode() } },
                    onVerify: { Task { await verifyCode() } }
                )
                .transition(isAdvancing ? forwardTransition : backwardTransition)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { hideKeyboard() }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
        .onChange(of: code) { _ in
            if step == .enterCode && !errorText.isEmpty {
                errorText = ""
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Actions

    private func sendCode() async {
        guard canContinueBase else { return }
        guard net.isConnected else {
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
            self.isAdvancing = true
            self.step = .enterCode

        } catch {
            if let nsError = error as NSError?,
               let code = AuthErrorCode(rawValue: nsError.code) {

                switch code {
                case .invalidPhoneNumber:
                    self.errorText = "Please enter a valid 10-digit US number."
                    self.showErrorBorder = true

                case .tooManyRequests, .quotaExceeded:
                    self.errorText = "Too many attempts. Please wait a few minutes and try again."

                case .captchaCheckFailed:
                    self.errorText = "Verification failed. Please try again and ensure Safari is available."

                case .appNotAuthorized:
                    self.errorText = "App isn't authorized for phone auth. Please update and try again."

                default:
                    self.errorText = "Failed to send code. Please try again."
                }
            } else {
                self.errorText = "Failed to send code. Please try again."
            }

            print("verifyPhone error:", error)
        }
    }

    private func verifyCode() async {
        guard let verID = verificationID else { return }
        guard net.isConnected else {
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

            do {
                _ = try await functions.httpsCallable("triggerWelcome").call([:])
            } catch {
                print("triggerWelcome error:", error.localizedDescription)
            }
        } catch {
            self.errorText = "Invalid or expired code. Please try again."
            print("signIn error:", error)
        }
    }
}

