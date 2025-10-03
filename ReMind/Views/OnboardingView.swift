// ============================
// File: Views/OnboardingView.swift
// ============================
import SwiftUI
import UIKit
import FirebaseAuth

struct OnboardingView: View {
    @EnvironmentObject private var appVM: AppViewModel

    enum Step { case enterPhone, enterCode }
    @State private var step: Step = .enterPhone

    // Phone entry (store DIGITS ONLY; format only for display)
    @State private var phoneDigits: String = ""        // "5551234567"
    @State private var showErrorBorder = false
    @State private var errorText: String = ""

    // Code entry
    @State private var verificationID: String?
    @State private var code: String = ""

    // Spinners
    @State private var isSending = false
    @State private var isVerifying = false

    private var isValidPhone: Bool { phoneDigits.count == 10 }

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
                case .enterPhone: phoneEntryContent
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

            // Bottom region: consent + button + links
            if step == .enterPhone {
                consentAndAgreeBottom
            }
        }
        .padding(.horizontal)
        .animation(.default, value: step)
        .animation(.default, value: errorText)
        .animation(.easeInOut, value: isValidPhone)
    }

    // MARK: - Subviews

    private var phoneEntryContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhoneField(digits: $phoneDigits)
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke((isValidPhone || !showErrorBorder) ? Color.gray.opacity(0.2) : .red, lineWidth: 1)
                )
                .onChange(of: phoneDigits) { newVal in
                    showErrorBorder = !(newVal.count == 10) && !newVal.isEmpty
                    if newVal.isEmpty { errorText = "" }
                }

            if showErrorBorder && !isValidPhone && !phoneDigits.isEmpty {
                Text("Please enter a valid 10-digit US number like (123)-456-7890.")
                    .font(.footnote)
                    .foregroundColor(.red)
            } else {
                Text("We’ll only use this to text your affirmations back to you later.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var consentAndAgreeBottom: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(consentMessage)
                .font(.caption2)
                .multilineTextAlignment(.leading)
                .foregroundColor(.black) // always black
                .accessibilityIdentifier("ConsentMessage")

            Button {
                Task { await sendCode() }
            } label: {
                ZStack {
                    Text(isSending
                         ? "Sending…"
                         : (isValidPhone ? "Agree & Continue" : "Agree to Continue"))
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
            .accessibilityIdentifier("AgreeAndContinueButton")

            // Links to Terms and Privacy
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

    private var codeEntry: some View {
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
        errorText = ""
        isVerifying = true
        defer { isVerifying = false }

        let credential = PhoneAuthProvider.provider()
            .credential(withVerificationID: verID, verificationCode: code)

        do {
            _ = try await Auth.auth().signIn(with: credential)
            await appVM.setPhoneProfileAndLoad(phoneDigits)
        } catch {
            self.errorText = "Invalid or expired code. Please try again."
            print("signIn error:", error)
        }
    }
}

// MARK: - UIKit-backed phone field
private struct PhoneField: UIViewRepresentable {
    @Binding var digits: String

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.placeholder = "(123)-456-7890"
        tf.keyboardType = .numberPad
        tf.textContentType = .telephoneNumber
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.clearButtonMode = .never
        tf.delegate = context.coordinator
        tf.text = Coordinator.format(digits)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if !uiView.isFirstResponder {
            let formatted = Coordinator.format(digits)
            if uiView.text != formatted {
                uiView.text = formatted
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(digits: $digits)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var digits: String

        init(digits: Binding<String>) {
            _digits = digits
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            let currentFormatted = textField.text ?? ""
            let currentDigits = digits

            let isBackspace = string.isEmpty && range.length == 1
            let charBeingDeleted: Character? = {
                guard range.location < currentFormatted.count else { return nil }
                let idx = currentFormatted.index(currentFormatted.startIndex, offsetBy: range.location)
                return currentFormatted[idx]
            }()

            var startDigitIdx = Self.digitIndex(forFormattedIndex: range.location, in: currentFormatted)
            var endDigitIdx   = Self.digitIndex(forFormattedIndex: range.location + range.length, in: currentFormatted)

            if isBackspace, let ch = charBeingDeleted, !ch.isNumber {
                startDigitIdx = max(0, startDigitIdx - 1)
                endDigitIdx = startDigitIdx + 1
            }

            let replacementDigits = string.filter(\.isNumber)

            var newDigits = currentDigits
            let start = max(0, min(startDigitIdx, newDigits.count))
            let end   = max(0, min(endDigitIdx,   newDigits.count))
            if start <= end {
                let prefix = newDigits.prefix(start)
                let suffix = newDigits.dropFirst(end)
                newDigits = String(prefix) + replacementDigits + String(suffix)
            }
            if newDigits.count > 10 { newDigits = String(newDigits.prefix(10)) }

            if digits != newDigits { digits = newDigits }

            let newFormatted = Self.format(newDigits)
            if textField.text != newFormatted {
                textField.text = newFormatted
            }

            let targetDigitCaret = start + replacementDigits.count
            let caretPos = Self.formattedIndex(forDigitIndex: targetDigitCaret, in: newFormatted)

            if let position = textField.position(from: textField.beginningOfDocument, offset: caretPos) {
                textField.selectedTextRange = textField.textRange(from: position, to: position)
            }

            return false
        }

        static func digitIndex(forFormattedIndex idx: Int, in formatted: String) -> Int {
            guard idx > 0 else { return 0 }
            var count = 0
            var i = 0
            for ch in formatted {
                if i >= idx { break }
                if ch.isNumber { count += 1 }
                i += 1
            }
            return count
        }

        static func formattedIndex(forDigitIndex digitIndex: Int, in formatted: String) -> Int {
            var seen = 0
            var i = 0
            for ch in formatted {
                if ch.isNumber {
                    if seen == digitIndex { return i }
                    seen += 1
                }
                i += 1
            }
            return formatted.count
        }

        static func format(_ digits: String) -> String {
            let s = String(digits.prefix(10))
            switch s.count {
            case 0: return ""
            case 1...3:
                return "(\(s))"
            case 4...6:
                let area = s.prefix(3)
                let mid  = s.dropFirst(3)
                return "(\(area))-\(mid)"
            default:
                let area = s.prefix(3)
                let mid  = s.dropFirst(3).prefix(3)
                let last = s.dropFirst(6)
                return "(\(area))-\(mid)-\(last)"
            }
        }
    }
}
