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

    var body: some View {
        ScrollView {
            VStack {
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

                    CodeEntrySection(
                        code: $code,
                        phoneNumber: phoneNumber,
                        onEditNumber: onBack,
                        onResend: onResend,
                        showTopBar: false
                    )
                    .onboardingCardStyle()
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
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { didAppear = true }
    }
}
