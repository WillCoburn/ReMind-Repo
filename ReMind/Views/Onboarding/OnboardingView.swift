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
    @State private var isKeyboardVisible = false

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

    private var formattedPhoneDisplay: String {
        let formatted = PhoneField.Coordinator.format(phoneDigits)
        let base = formatted.isEmpty ? phoneDigits : formatted
        return "+1 \(base)"
    }
    
    private let consentMessage =
    """
    By tapping 'Continue', you consent to receive reminder text messages from ReMind.
    """

    var body: some View {
        ZStack {

            Image("MainBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            switch step {
            case .enterPhone:
                phoneEntryLayout

            case .enterCode:
                codeEntryLayout
                
            }

        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                if isKeyboardVisible {
                    hideKeyboard()
                }
            },
            including: .gesture
        )
        .animation(.default, value: step)
        .animation(.default, value: errorText)
        .animation(.easeInOut, value: isValidPhone)
        .animation(.easeInOut, value: isKeyboardVisible)



        .onChange(of: net.isConnected) { value in
            print("🔄 net.isConnected ->", value)
        }
        
        .onChange(of: code) { _ in
            if step == .enterCode && !errorText.isEmpty {
                errorText = ""
            }
        }


        // 👇 Track keyboard visibility to hide the subtitle
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }

        // Force light appearance for this screen
        .preferredColorScheme(.light)
    }

    private var phoneEntryLayout: some View {
         VStack(spacing: 24) {

             // MARK: - Header / Logo
             VStack(spacing: isKeyboardVisible ? 4 : 10) {
                 Image("FullLogo")
                     .resizable()
                     .scaledToFit()
                     .frame(width: 300, height: 120)   // tune as needed
                     .padding(.top, 4)

                 // 👇 Hide this text when keyboard is visible
                 if !isKeyboardVisible {
                     Text("Enter your phone number to continue.")
                         .font(.title2.weight(.semibold))
                         .multilineTextAlignment(.center)
                         .padding(.horizontal, 16)
                         .transition(.opacity.combined(with: .move(edge: .top)))
                 }
             }
             .fixedSize(horizontal: false, vertical: true)
             .padding(.top, 24)

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
                     .padding(.horizontal)
                     .transition(.opacity.combined(with: .move(edge: .top)))
             }

             Spacer(minLength: 16)

             ConsentAndAgreeBottom(
                 hasConsented: $hasConsented,
                 consentMessage: consentMessage,
                 canContinue: canContinueOnline, // 👈 pass online-aware flag
                 isSending: isSending,
                 onAgreeAndContinue: {
                     Task { await sendCode() }
                 }
             )
             .padding(.bottom, 24)
         }
         .padding(.horizontal, 24)
     }

     private var codeEntryLayout: some View {
         VStack(alignment: .leading) {
             CodeEntrySection(
                 code: $code,
                 phoneNumber: formattedPhoneDisplay,
                 errorText: errorText,
                 isVerifying: isVerifying,
                 onEditNumber: {
                     step = .enterPhone
                     errorText = ""
                     code = ""
                 },
                 onResend: {
                     Task { await sendCode() }
                 },
                 onVerify: {
                     Task { await verifyCode() }
                 }
             )
             .padding(.horizontal, 24)
             .padding(.top, 24)

             Spacer()
         }
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
            self.step = .enterCode
        } catch {
            self.errorText = "Failed to send code. Please try again."
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
