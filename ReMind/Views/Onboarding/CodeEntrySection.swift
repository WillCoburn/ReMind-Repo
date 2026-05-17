import SwiftUI
import UIKit

struct CodeEntrySection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var code: String
    let phoneNumber: String
    let onEditNumber: () -> Void
    let onResend: () -> Void

    var showTopBar: Bool = true

    @State private var isCodeFieldFocused = false

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            if showTopBar {
                topBar
            }

            VStack(alignment: .center, spacing: 10) {
                Text("Enter verification code")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)

                (Text("We sent a 6-digit code to ") +
                 Text(phoneNumber).foregroundColor(.figmaBlue))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
            }

            codeBoxes

            Button("Resend code", action: onResend)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.figmaBlue)
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(0.9)
                .frame(minHeight: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 44 : 32)
        }
        .padding(.top, showTopBar ? 4 : 0)
        .onAppear {
            isCodeFieldFocused = true
        }
        .brainMailDynamicTypeRange()
    }

    private var topBar: some View {
        HStack {
            Button(action: onEditNumber) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(8)
            }
            Spacer()
        }
    }

    private var codeBoxes: some View {
        GeometryReader { proxy in
            let metrics = codeBoxMetrics(for: proxy.size.width)
            let digits = Array(code)

            ZStack {
                HStack(spacing: metrics.spacing) {
                    ForEach(0..<6, id: \.self) { index in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(borderColor(for: index), lineWidth: index == code.count && code.count < 6 ? 2 : 1)

                            Text(index < digits.count ? String(digits[index]) : "")
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                                .scaleEffect(index < digits.count ? 1 : 0.94)
                                .opacity(index < digits.count ? 1 : 0.25)
                                .animation(.easeOut(duration: 0.18), value: code)
                        }
                        .frame(width: metrics.width, height: metrics.height)
                        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 4)
                        .animation(.easeInOut(duration: 0.2), value: code)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                OneTimeCodeTextField(
                    code: $code,
                    isFirstResponder: $isCodeFieldFocused
                )
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
        }
        .frame(height: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 74 : 64)
        .contentShape(Rectangle())
        .onTapGesture {
            isCodeFieldFocused = true
        }
        .onAppear {
            DispatchQueue.main.async {
                isCodeFieldFocused = true
            }
        }
    }

    private func codeBoxMetrics(for availableWidth: CGFloat) -> (width: CGFloat, height: CGFloat, spacing: CGFloat) {
        let minimumWidth: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 30 : 34
        let maximumWidth: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 44 : 46
        let minimumSpacing: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 5 : 6
        let maximumSpacing: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 10 : 12
        let spacing = min(maximumSpacing, max(minimumSpacing, (availableWidth - minimumWidth * 6) / 5))
        let width = min(maximumWidth, max(minimumWidth, (availableWidth - spacing * 5) / 6))
        return (width, max(48, width * 1.2), spacing)
    }

    private func borderColor(for index: Int) -> Color {
        if index == code.count && code.count < 6 { return .figmaBlue }
        if index < code.count { return .figmaBlue.opacity(0.45) }
        return Color.gray.opacity(0.3)
    }
}

private struct OneTimeCodeTextField: UIViewRepresentable {
    @Binding var code: String
    @Binding var isFirstResponder: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(code: $code, isFirstResponder: $isFirstResponder)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        textField.textAlignment = .center
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.smartInsertDeleteType = .no
        textField.textColor = .clear
        textField.tintColor = .clear
        textField.backgroundColor = .clear
        textField.accessibilityLabel = "Verification code"
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != code {
            textField.text = code
        }

        if isFirstResponder && !textField.isFirstResponder {
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var code: String
        @Binding private var isFirstResponder: Bool

        init(code: Binding<String>, isFirstResponder: Binding<Bool>) {
            _code = code
            _isFirstResponder = isFirstResponder
        }

        @objc func textDidChange(_ textField: UITextField) {
            updateCode(from: textField.text ?? "", in: textField)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFirstResponder = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFirstResponder = false
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            updateCode(from: textField.text ?? "", in: textField)
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let currentText = textField.text ?? ""
            guard let textRange = Range(range, in: currentText) else {
                updateCode(from: string, in: textField)
                return false
            }

            let proposedText = currentText.replacingCharacters(in: textRange, with: string)
            updateCode(from: proposedText, in: textField)
            moveCaretToEnd(in: textField)
            return false
        }

        private func updateCode(from text: String, in textField: UITextField) {
            let digits = text.filter(\.isNumber)
            let sanitized = String(digits.prefix(6))
            if code != sanitized {
                code = sanitized
            }
            if textField.text != sanitized {
                textField.text = sanitized
            }
        }

        private func moveCaretToEnd(in textField: UITextField) {
            guard let end = textField.position(from: textField.beginningOfDocument, offset: textField.text?.count ?? 0) else {
                return
            }
            textField.selectedTextRange = textField.textRange(from: end, to: end)
        }
    }
}
