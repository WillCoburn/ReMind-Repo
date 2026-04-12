import SwiftUI

struct PhoneEntryScreen: View {
    @Binding var phoneDigits: String
    @Binding var showErrorBorder: Bool
    @Binding var errorText: String
    @Binding var hasConsented: Bool

    let isSending: Bool
    let isValidPhone: Bool
    let consentMessage: String
    let canContinue: Bool
    let onContinue: () -> Void

    @State private var didAppear = false

    var body: some View {
        ZStack {
            OnboardingBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack {
                    VStack(alignment: .center, spacing: 28) {
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
                    .frame(maxWidth: 460)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            didAppear = true
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Welcome in!")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 8)
        .animation(.easeOut(duration: 0.4).delay(0.08), value: didAppear)
    }

    private var consentAndContinue: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        hasConsented.toggle()
                    } label: {
                        Image(systemName: hasConsented ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(hasConsented ? Color.figmaBlue : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    Text(consentMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 4) {
                    Link("Terms & Conditions", destination: URL(string: "https://re-mind-app.github.io/remind-site/terms.html")!)
                        .underline()
                    Text("·")
                    Link("Privacy", destination: URL(string: "https://re-mind-app.github.io/remind-site/privacy.html")!)
                        .underline()
                }
                .font(.footnote)
                .foregroundStyle(Color.figmaBlue)
                .tint(.figmaBlue)
                .frame(maxWidth: .infinity, alignment: .center)
            }

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
        }
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
