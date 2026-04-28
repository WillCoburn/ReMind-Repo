import SwiftUI
import UIKit

struct CodeEntrySection: View {
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
        }
        .padding(.top, showTopBar ? 4 : 0)
        .onAppear {
            otpDebugLog("CodeEntrySection appeared; requesting focus")
            isCodeFieldFocused = true
        }
        .onChange(of: code) { newValue in
            otpDebugLog("SwiftUI code binding changed; count=\(newValue.count)")
        }
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
            let _ = otpDebugLog("rendering code boxes; count=\(code.count), availableWidth=\(Int(proxy.size.width))")
            let metrics = codeBoxMetrics(for: proxy.size.width)

            ZStack {
                HStack(spacing: metrics.spacing) {
                let digits = Array(code)

                ForEach(0..<6, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)

                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(borderColor(for: index), lineWidth: index == code.count && code.count < 6 ? 2 : 1)

                        Text(index < digits.count ? String(digits[index]) : "")
                            .font(.title3.weight(.semibold))
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
        .frame(height: 64)
        .contentShape(Rectangle())
        .onTapGesture {
            otpDebugLog("OTP row tapped; requesting focus")
            isCodeFieldFocused = true
        }
        .onAppear {
            DispatchQueue.main.async {
                otpDebugLog("OTP row async focus request")
                isCodeFieldFocused = true
            }
        }
    }

    private func codeBoxMetrics(for availableWidth: CGFloat) -> (width: CGFloat, height: CGFloat, spacing: CGFloat) {
        let minimumWidth: CGFloat = 34
        let maximumWidth: CGFloat = 46
        let minimumSpacing: CGFloat = 6
        let maximumSpacing: CGFloat = 12
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

private func otpDebugLog(_ message: String) {
    #if DEBUG
    print("🔢 [OTP] \(message)")
    #endif
}

private struct OneTimeCodeTextField: UIViewRepresentable {
    @Binding var code: String
    @Binding var isFirstResponder: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(code: $code)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        textField.textAlignment = .center
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartInsertDeleteType = .no
        textField.textColor = .clear
        textField.tintColor = .clear
        textField.backgroundColor = .clear
        otpDebugLog("created UIKit one-time-code field")
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != code {
            otpDebugLog("syncing UIKit field from binding; bindingCount=\(code.count), fieldCount=\(textField.text?.count ?? 0)")
            textField.text = code
        }

        if isFirstResponder && !textField.isFirstResponder {
            DispatchQueue.main.async {
                let didFocus = textField.becomeFirstResponder()
                otpDebugLog("becomeFirstResponder requested; success=\(didFocus)")
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var code: String

        init(code: Binding<String>) {
            _code = code
        }

        @objc func textDidChange(_ textField: UITextField) {
            otpDebugLog("editingChanged; fieldCount=\((textField.text ?? "").count)")
            updateCode(from: textField.text ?? "", in: textField)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            otpDebugLog("textFieldDidBeginEditing; isFirstResponder=\(textField.isFirstResponder)")
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            otpDebugLog("textFieldDidEndEditing")
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            otpDebugLog("textFieldDidChangeSelection; fieldCount=\((textField.text ?? "").count)")
            updateCode(from: textField.text ?? "", in: textField)
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            otpDebugLog("shouldChange; replacementCount=\(string.count), range={\(range.location),\(range.length)}")
            return true
        }

        private func updateCode(from text: String, in textField: UITextField) {
            let digits = text.filter(\.isNumber)
            let sanitized = String(digits.prefix(6))
            if code != sanitized {
                otpDebugLog("updating binding from UIKit; oldCount=\(code.count), newCount=\(sanitized.count)")
                code = sanitized
            }
            if textField.text != sanitized {
                otpDebugLog("sanitizing UIKit field text; fieldCount=\((textField.text ?? "").count), sanitizedCount=\(sanitized.count)")
                textField.text = sanitized
            }
        }
    }
}
