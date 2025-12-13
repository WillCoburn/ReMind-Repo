// ============================
// File: Views/Onboarding/CodeEntrySection.swift
// ============================
import SwiftUI

struct CodeEntrySection: View {
    @Binding var code: String
    let phoneNumber: String
    let onEditNumber: () -> Void
    let onResend: () -> Void

    @FocusState private var isCodeFieldFocused: Bool

    // Only allow digits & max length 6
    private var sanitizedBinding: Binding<String> {
        Binding(
            get: { code },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)
                code = String(digits.prefix(6))
            }
        )
    }

    var body: some View {
        VStack(alignment: .center, spacing: 24) {

            HStack {
                Button(action: onEditNumber) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                }
                Spacer()
            }

            VStack(alignment: .center, spacing: 8) {
                Text("Phone Verification")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)

                (Text("We've sent an SMS with an activation code to your phone ") +
                 Text(phoneNumber).foregroundColor(.figmaBlue))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
            }

            codeBoxes

            Button("Resend code", action: onResend)
                .font(.body.weight(.medium))
                .foregroundColor(.figmaBlue)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 4)
        .onAppear { isCodeFieldFocused = true }
    }

    private var codeBoxes: some View {
        ZStack {
            HStack(spacing: 14) {
                let digits = Array(code)

                ForEach(0..<6, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor(for: index), lineWidth: 2)
                            .frame(width: 48, height: 48)
                            .animation(.easeInOut(duration: 0.15), value: code)

                        Text(index < digits.count ? String(digits[index]) : "")
                            .font(.title2.weight(.semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            TextField("", text: sanitizedBinding)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isCodeFieldFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { isCodeFieldFocused = true }
    }

    private func borderColor(for index: Int) -> Color {
        if index == code.count && code.count < 6 { return .figmaBlue }
        return Color.gray.opacity(0.35)
    }
}
