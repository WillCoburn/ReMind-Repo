import SwiftUI

struct CodeEntrySection: View {
    @Binding var code: String
    let phoneNumber: String
    let onEditNumber: () -> Void
    let onResend: () -> Void

    var showTopBar: Bool = true

    @FocusState private var isCodeFieldFocused: Bool

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
        .onAppear { isCodeFieldFocused = true }
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

                TextField("", text: sanitizedBinding)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isCodeFieldFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
            }
        }
        .frame(height: 64)
        .contentShape(Rectangle())
        .onTapGesture { isCodeFieldFocused = true }
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
