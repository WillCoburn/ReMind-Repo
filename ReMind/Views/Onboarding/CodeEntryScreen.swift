import SwiftUI

struct CodeEntryScreen: View {
    @Binding var code: String
    let phoneNumber: String

    let errorText: String
    let isVerifying: Bool

    let onBack: () -> Void
    let onResend: () -> Void
    let onVerify: () -> Void

    @State private var didAppear = false
    @State private var messageIsArriving = false

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = OnboardingLayout.formHorizontal(for: proxy.size.width)
            let contentWidth = OnboardingLayout.contentWidth(
                in: proxy.size.width,
                horizontalPadding: horizontalPadding
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(8)
                        }
                        .contentShape(Rectangle())
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    CodeMessageIllustration(
                        messageIsArriving: messageIsArriving
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(didAppear ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.06), value: didAppear)

                    CodeEntrySection(
                        code: $code,
                        phoneNumber: phoneNumber,
                        onEditNumber: onBack,
                        onResend: onResend,
                        showTopBar: false
                    )
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 10)
                    .animation(.easeOut(duration: 0.4).delay(0.12), value: didAppear)

                    if !errorText.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(errorText)
                        }
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.opacity)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: onVerify) {
                        ZStack {
                            Text(isVerifying ? "Verifying…" : "Verify Code")
                                .font(.headline.weight(.semibold))
                                .opacity(isVerifying ? 0 : 1)

                            if isVerifying {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    }
                    .buttonStyle(
                        OnboardingPrimaryButtonStyle(
                            isEnabled: code.count == 6 && !isVerifying,
                            accentColor: .figmaBlue
                        )
                    )
                    .disabled(code.count < 6 || isVerifying)
                    .padding(.horizontal, 4)
                }
                .frame(width: contentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(OnboardingBackgroundView().ignoresSafeArea())
        .onAppear {
            didAppear = true
            messageIsArriving = true
        }
    }
}

private struct CodeMessageIllustration: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let messageIsArriving: Bool

    var body: some View {
        let illustrationSize: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 112 : 132
        let phoneWidth: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 66 : 76
        let phoneHeight: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 98 : 112

        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.figmaBlue, lineWidth: 5)
                .frame(width: phoneWidth, height: phoneHeight)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.figmaBlue.opacity(0.35))
                        .frame(width: 28, height: 4)
                        .padding(.top, 10)
                }
                .overlay(alignment: .bottom) {
                    Circle()
                        .stroke(Color.figmaBlue.opacity(0.35), lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .padding(.bottom, 9)
                }

            MessageBubbleTail()
                .fill(Color.figmaBlue.opacity(0.12))
                .frame(width: 58, height: 38)
                .overlay {
                    MessageBubbleTail()
                        .stroke(Color.figmaBlue, lineWidth: 3)
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.figmaBlue)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .offset(x: messageIsArriving ? 34 : 26, y: messageIsArriving ? -22 : -28)
                .opacity(0.95)
        }
        .frame(width: illustrationSize, height: illustrationSize)
        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: messageIsArriving)
        .accessibilityHidden(true)
    }
}

private struct MessageBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height * 0.82
        )
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: 14, height: 14))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.28, y: bubbleRect.maxY - 2))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.44, y: bubbleRect.maxY - 2))
        path.closeSubpath()
        return path
    }
}
