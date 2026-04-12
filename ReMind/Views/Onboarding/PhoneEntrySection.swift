import SwiftUI
import UIKit

struct PhoneEntrySection: View {
    @Binding var phoneDigits: String
    @Binding var showErrorBorder: Bool
    @Binding var errorText: String
    let isValidPhone: Bool

    private var borderColor: Color {
        (isValidPhone || !showErrorBorder) ? Color.gray.opacity(0.25) : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Phone number")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Text("+1")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)

                Divider()
                    .frame(height: 24)

                PhoneField(digits: $phoneDigits)
                    .frame(height: 44)
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
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text("We only use this number for verification and your reminder texts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.systemGray6))
            )
        }
        .dynamicTypeSize(.medium)
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
