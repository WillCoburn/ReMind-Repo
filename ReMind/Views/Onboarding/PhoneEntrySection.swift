// ============================
// File: Views/Onboarding/PhoneEntrySection.swift
// ============================
import SwiftUI
import UIKit

struct PhoneEntrySection: View {
    @Binding var phoneDigits: String
    @Binding var showErrorBorder: Bool
    @Binding var errorText: String
    let isValidPhone: Bool

    var body: some View {
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
                    if newVal.isEmpty {
                        errorText = ""
                    }

                    // 👇 Automatically dismiss keyboard when 10 digits entered
                    if newVal.count == 10 {
                        hideKeyboard()
                    }
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
}

// MARK: - Keyboard Dismiss Helper
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
