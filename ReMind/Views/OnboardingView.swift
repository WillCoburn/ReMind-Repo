// Views/OnboardingView.swift
import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var appVM: AppViewModel

    // The text shown in the TextField (already formatted as (xxx)-xxx-xxxx)
    @State private var phone: String = ""
    // Simple flag to control when to show the error (only after user starts typing)
    @State private var showError: Bool = false

    private var digitsOnly: String {
        phone.filter(\.isNumber)
    }

    private var isValidPhone: Bool {
        digitsOnly.count == 10
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("ReMind")
                .font(.system(size: 44, weight: .bold))

            Text("Celebrate when it's all clear, and prepare for when it's not.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your Phone Number")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("(123)-456-7890", text: $phone)
                    .keyboardType(UIKeyboardType.numberPad)
                    .textContentType(UIKit.UITextContentType.telephoneNumber)
                    .onChange(of: phone) { newValue in
                        // Reformat as the user types; keep only up to 10 digits
                        let formatted = Self.formatPhone(newValue)
                        if formatted != phone { phone = formatted }
                        if !newValue.isEmpty { showError = true }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isValidPhone || !showError ? Color.gray.opacity(0.2) : Color.red, lineWidth: 1)
                    )

                if showError && !isValidPhone && !phone.isEmpty {
                    Text("Please enter a valid 10-digit US number in the format (123)-456-7890 :)")
                        .font(.footnote)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("We will only use this to text your affirmations back to you later.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            Button(action: {
                Task { await appVM.onboard(phone: digitsOnly) } // send raw digits to backend
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidPhone ? Color.black : Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .disabled(!isValidPhone)

            Spacer()

            Text("By continuing you agree to our Terms & Privacy.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
    }
}

// MARK: - Formatter
extension OnboardingView {
    /// Formats any string into "(xxx)-xxx-xxxx" using at most 10 digits.
    static func formatPhone(_ input: String) -> String {
        // Keep only digits; cap at 10
        let digits = input.filter(\.isNumber).prefix(10)
        let count = digits.count
        var result = ""

        let array = Array(digits)

        switch count {
        case 0:
            result = ""
        case 1...3:
            // (x, (xx, (xxx
            result = "(\(String(array)))"
        case 4...6:
            // (xxx)-x... (xxx)-xxx
            let area = String(array[0..<3])
            let mid = String(array[3..<count])
            result = "(\(area))-\(mid)"
        default: // 7...10
            let area = String(array[0..<3])
            let mid  = String(array[3..<6])
            let last = String(array[6..<count])
            result = "(\(area))-\(mid)-\(last)"
        }

        return result
    }
}
