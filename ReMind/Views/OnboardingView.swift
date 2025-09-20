// ============================
// File: Views/OnboardingView.swift
// ============================
import SwiftUI
import UIKit
import FirebaseAuth

struct OnboardingView: View {
    @EnvironmentObject private var appVM: AppViewModel

    // Step state
    enum Step { case enterPhone, enterCode }
    @State private var step: Step = .enterPhone

    // Phone entry
    @State private var phone: String = ""             // shown as (xxx)-xxx-xxxx
    @State private var showErrorBorder = false        // draws red border while typing invalid
    @State private var errorText: String = ""         // inline text error

    // Code entry
    @State private var verificationID: String?
    @State private var code: String = ""

    // Spinners
    @State private var isSending = false
    @State private var isVerifying = false

    // Derived
    private var digitsOnly: String { phone.filter(\.isNumber) }
    private var isValidPhone: Bool { digitsOnly.count == 10 }

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
                case .enterPhone: phoneEntry
                case .enterCode:  codeEntry
                }
            }

            if !errorText.isEmpty {
                Text(errorText)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            Text("By continuing you agree to our Terms & Privacy.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 12)
        }
        .padding(.horizontal)
        .animation(.default, value: step)
        .animation(.default, value: errorText)
    }

    // MARK: - Subviews

    private var phoneEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Phone Number")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("(123)-456-7890", text: $phone)
                .keyboardType(UIKeyboardType.numberPad)
                .textContentType(UIKit.UITextContentType.telephoneNumber)
                .onChange(of: phone) { newValue in
                    let formatted = Self.formatPhone(newValue)
                    if formatted != phone { phone = formatted }
                    showErrorBorder = !isValidPhone && !newValue.isEmpty
                    if newValue.isEmpty { errorText = "" }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke((isValidPhone || !showErrorBorder) ? Color.gray.opacity(0.2) : .red, lineWidth: 1)
                )

            if showErrorBorder && !isValidPhone && !phone.isEmpty {
                Text("Please enter a valid 10-digit US number like (123)-456-7890.")
                    .font(.footnote)
                    .foregroundColor(.red)
            } else {
                Text("We’ll only use this to text your affirmations back to you later.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button {
                Task { await sendCode() }
            } label: {
                ZStack {
                    Text(isSending ? "Sending…" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .opacity(isSending ? 0 : 1)
                    if isSending { ProgressView().padding(.vertical) }
                }
                .background(isValidPhone ? Color.black : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(!isValidPhone || isSending)
        }
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enter Verification Code")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("123456", text: $code)
                .keyboardType(UIKeyboardType.numberPad)
                .textContentType(UIKit.UITextContentType.oneTimeCode)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

            HStack {
                Button("Edit number") {
                    step = .enterPhone
                    errorText = ""
                    code = ""
                }

                Spacer()

                Button {
                    Task { await verifyCode() }
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

    // MARK: - Actions

    private func sendCode() async {
        guard isValidPhone else { return }
        errorText = ""
        isSending = true
        defer { isSending = false }

        // Convert to E.164 for US numbers: +1XXXXXXXXXX
        let e164 = "+1\(digitsOnly)"

        do {
            // If you added a Testing Phone Number in Firebase Auth,
            // this completes instantly without sending an SMS.
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
        errorText = ""
        isVerifying = true
        defer { isVerifying = false }

        let credential = PhoneAuthProvider.provider()
            .credential(withVerificationID: verID, verificationCode: code)

        do {
            _ = try await Auth.auth().signIn(with: credential)
            // Persist a minimal profile and switch UI to MainView
            await appVM.setPhoneProfileAndLoad(digitsOnly)
        } catch {
            self.errorText = "Invalid or expired code. Please try again."
            print("signIn error:", error)
        }
    }
}

// MARK: - Formatter
extension OnboardingView {
    /// Formats any string into "(xxx)-xxx-xxxx" using at most 10 digits.
    static func formatPhone(_ input: String) -> String {
        let digits = input.filter(\.isNumber).prefix(10)
        let a = Array(digits)
        switch a.count {
        case 0: return ""
        case 1...3:
            return "(\(String(a)))"
        case 4...6:
            let area = String(a[0..<3])
            let mid  = String(a[3..<a.count])
            return "(\(area))-\(mid)"
        default:
            let area = String(a[0..<3])
            let mid  = String(a[3..<6])
            let last = String(a[6..<a.count])
            return "(\(area))-\(mid)-\(last)"
        }
    }
}
