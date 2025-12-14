// ============================
// File: Views/Onboarding/PhoneEntryScreen.swift
// ============================
import SwiftUI
import UIKit

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

    @State private var keyboardHeight: CGFloat = 0
    @State private var bottomBarHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {

            // ✅ Main content (never moves with keyboard)
            VStack(spacing: 0) {
                topContent
                    .padding(.top, 36)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Phone")
                        .font(.headline)

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
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // ✅ Reserve room equal to the bottom bar’s visible height
                // so lifting the bar won’t overlap the phone field/header.
                Spacer(minLength: bottomBarHeight + 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // ✅ Bottom bar, lifted exactly by the keyboard overlap
            VStack {
                Spacer(minLength: 0)

                ConsentAndAgreeBottom(
                    hasConsented: $hasConsented,
                    consentMessage: consentMessage,
                    canContinue: canContinue,
                    isSending: isSending,
                    onAgreeAndContinue: onContinue
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .readSize { size in
                    // capture the natural height of the bottom component
                    bottomBarHeight = size.height + 16
                }
            }
            .padding(.bottom, keyboardHeight)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: keyboardHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // ✅ Critical: stop SwiftUI from also auto-insetting for keyboard
        .ignoresSafeArea(.keyboard, edges: .all)

        // ✅ Keyboard tracking (overlap height)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            keyboardHeight = Self.keyboardOverlapHeight(from: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private var topContent: some View {
        VStack(spacing: 10) {
            Image("FullLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 110)

            Text("Enter your phone number to continue.")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Keyboard overlap calculation
    private static func keyboardOverlapHeight(from note: Notification) -> CGFloat {
        guard
            let info = note.userInfo,
            let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return 0 }

        let window = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        guard let window else { return 0 }

        let screenHeight = window.bounds.height
        let safeBottom = window.safeAreaInsets.bottom

        let keyboardTopY = endFrame.minY
        let covered = max(0, screenHeight - keyboardTopY)

        // subtract home indicator inset so we don’t over-lift
        return max(0, covered - safeBottom)
    }
}

// MARK: - Measure child size
private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private extension View {
    func readSize(_ onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: SizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}
