import SwiftUI
import UIKit

struct PhoneEntrySection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var phoneDigits: String
    @Binding var showErrorBorder: Bool
    @Binding var errorText: String
    let isValidPhone: Bool

    private var borderColor: Color {
        (isValidPhone || !showErrorBorder) ? Color.gray.opacity(0.25) : .red
    }

    var body: some View {
        let fieldHeight: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 56 : 44
        let dividerHeight: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 34 : 24

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("+1")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)

                Divider()
                    .frame(height: dividerHeight)

                PhoneField(digits: $phoneDigits)
                    .frame(minHeight: fieldHeight)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.18), value: showErrorBorder)
            .onChange(of: phoneDigits) { newVal in
                showErrorBorder = !(newVal.count == 10) && !newVal.isEmpty
                if newVal.isEmpty { errorText = "" }
                if newVal.count == 10 { hideKeyboard() }
            }

            if showErrorBorder && !isValidPhone && !phoneDigits.isEmpty {
                Text("Please enter a valid 10-digit US number like (123)-456-7890.")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .brainMailDynamicTypeRange()
    }
}

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
