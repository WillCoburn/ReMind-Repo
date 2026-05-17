import SwiftUI

struct PhoneEntryScreen: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var phoneDigits: String
    @Binding var showErrorBorder: Bool
    @Binding var errorText: String
    @Binding var hasConsented: Bool

    let isSending: Bool
    let isValidPhone: Bool
    let canContinue: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var didAppear = false
    @State private var logoIsFloating = false
    @State private var waveIsDrifting = false

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = OnboardingLayout.formHorizontal(for: proxy.size.width)
            let contentWidth = OnboardingLayout.contentWidth(
                in: proxy.size.width,
                horizontalPadding: horizontalPadding
            )

            ScrollView {
                VStack(alignment: .center, spacing: 22) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())

                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    header

                    VStack(spacing: 10) {
                        PhoneEntrySection(
                            phoneDigits: $phoneDigits,
                            showErrorBorder: $showErrorBorder,
                            errorText: $errorText,
                            isValidPhone: isValidPhone
                        )

                        if !errorText.isEmpty {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                        }
                    }
                    .onboardingCardStyle()
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 10)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: didAppear)

                    consentAndContinue
                }
                .frame(width: contentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(OnboardingBackgroundView().ignoresSafeArea())
        .onAppear {
            didAppear = true
            hasConsented = true
            logoIsFloating = true
            waveIsDrifting = true
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            animatedLogo
                .padding(.bottom, 4)

            Text("Welcome in!")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Please enter your phone number to start sending yourself reminders.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 8)
        .animation(.easeOut(duration: 0.4).delay(0.08), value: didAppear)
    }

    private var animatedLogo: some View {
        let logoSize: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 108 : 132
        let waveHeight: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 28 : 34
        let waveBottomPadding: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 13 : 16

        return ZStack {
            logoImage
                .offset(y: logoIsFloating ? -2 : 2)
                .rotationEffect(.degrees(logoIsFloating ? 1.5 : -1.5))

            logoImage
                .offset(x: waveIsDrifting ? 5 : -5)
                .mask(alignment: .bottom) {
                    VStack {
                        Spacer()
                        Rectangle()
                            .frame(height: waveHeight)
                            .padding(.horizontal, 8)
                            .padding(.bottom, waveBottomPadding)
                    }
                }
                .opacity(0.24)
        }
        .frame(width: logoSize, height: logoSize)
        .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: logoIsFloating)
        .animation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true), value: waveIsDrifting)
        .accessibilityHidden(true)
    }

    private var logoImage: some View {
        let logoSize: CGFloat = dynamicTypeSize.brainMailUsesAccessibilityLayout ? 108 : 132

        return Image("BottleLogo")
            .resizable()
            .scaledToFit()
            .frame(width: logoSize, height: logoSize)
    }

    private var consentAndContinue: some View {
        VStack(spacing: 12) {
            Button(action: onContinue) {
                ZStack {
                    Text(isSending ? "Sending…" : "Continue")
                        .font(.headline.weight(.semibold))
                        .opacity(isSending ? 0 : 1)

                    if isSending {
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .buttonStyle(
                OnboardingPrimaryButtonStyle(
                    isEnabled: canContinue && !isSending,
                    accentColor: .figmaBlue
                )
            )
            .disabled(!canContinue || isSending)
            .padding(.horizontal, 4)

            Text("We'll only use your number for verification and reminders.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.figmaBlue.opacity(0.07))
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    termsLink
                    Text("·")
                    privacyLink
                }

                VStack(spacing: 4) {
                    termsLink
                    privacyLink
                }
            }
            .font(.footnote)
            .foregroundStyle(Color.figmaBlue)
            .tint(.figmaBlue)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var termsLink: some View {
        Link("Terms & Conditions", destination: URL(string: "https://re-mind-app.github.io/remind-site/terms.html")!)
            .underline()
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private var privacyLink: some View {
        Link("Privacy", destination: URL(string: "https://re-mind-app.github.io/remind-site/privacy.html")!)
            .underline()
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}


struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isEnabled ? accentColor : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

struct OnboardingCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
            )
    }
}

extension View {
    func onboardingCardStyle() -> some View {
        modifier(OnboardingCardBackground())
    }
}
