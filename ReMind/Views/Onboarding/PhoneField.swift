// ============================
// File: Components/PhoneField.swift
// ============================
import SwiftUI
import UIKit

struct PhoneField: UIViewRepresentable {
    @Binding var digits: String

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        let mediumTraits = UITraitCollection(preferredContentSizeCategory: .medium)
                tf.font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: mediumTraits)
                tf.adjustsFontForContentSizeCategory = false
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

        init(digits: Binding<String>) { _digits = digits }

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
            if textField.text != newFormatted { textField.text = newFormatted }
            let targetDigitCaret = start + replacementDigits.count
            let caretPos = Self.formattedIndex(forDigitIndex: targetDigitCaret, in: newFormatted)
            if let position = textField.position(from: textField.beginningOfDocument, offset: caretPos) {
                textField.selectedTextRange = textField.textRange(from: position, to: position)
            }
            return false
        }

        static func digitIndex(forFormattedIndex idx: Int, in formatted: String) -> Int {
            guard idx > 0 else { return 0 }
            var count = 0; var i = 0
            for ch in formatted {
                if i >= idx { break }
                if ch.isNumber { count += 1 }
                i += 1
            }
            return count
        }

        static func formattedIndex(forDigitIndex digitIndex: Int, in formatted: String) -> Int {
            var seen = 0; var i = 0
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
            case 1...3: return "(\(s))"
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
