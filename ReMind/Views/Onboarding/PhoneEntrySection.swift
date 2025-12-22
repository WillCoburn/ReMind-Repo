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

    @State private var isKeyboardVisible = false

    private var borderColor: Color {
        (isValidPhone || !showErrorBorder) ? Color.gray.opacity(0.3) : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ✅ ONLY animated element
            if isKeyboardVisible {
                HStack {
                    Spacer()
                    Image("FullLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 110)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeOut(duration: 0.22), value: isKeyboardVisible)
            }

            // Phone field
            HStack(spacing: 0) {

                // Country code (matches old formatting)
                HStack(spacing: 4) {
                    Text("+1")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .frame(width: 28)          // 👈 KEY FIX (prevents overlap)
                .padding(.horizontal, 6)

                Divider()
                    .frame(width: 1, height: 24)
                    .background(Color.gray.opacity(0.3))
                    .padding(.trailing, 8)

                PhoneField(digits: $phoneDigits)
                    .frame(height: 44)
            }


            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            .onChange(of: phoneDigits) { newVal in
                showErrorBorder = !(newVal.count == 10) && !newVal.isEmpty
                if newVal.isEmpty { errorText = "" }
                if newVal.count == 10 { hideKeyboard() }
            }

            // Validation error
            if showErrorBorder && !isValidPhone && !phoneDigits.isEmpty {
                Text("Please enter a valid 10-digit US number like (123)-456-7890.")
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            // ❌ Instant hide (no animation)
            if !isKeyboardVisible {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Text("We’ll only use this to text your own entries back to you.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.systemGray4))
                )
            }
        }
        .onAppear { startKeyboardObservers() }
        .onDisappear { stopKeyboardObservers() }
    }

    // MARK: - Keyboard Observation
    private func startKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in isKeyboardVisible = true }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in isKeyboardVisible = false }
    }

    private func stopKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Keyboard Dismiss Helper
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
