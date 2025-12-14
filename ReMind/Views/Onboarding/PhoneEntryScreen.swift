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

    private var isKeyboardVisible: Bool { keyboardHeight > 0 }

    var body: some View {
        ZStack(alignment: .top) {

            // ============================
            // MAIN CONTENT
            // ============================
            VStack(spacing: 0) {
                topContent
                    .padding(.top, 36)
                    .padding(.horizontal, 24)

                // 🔑 This container now owns vertical positioning
                VStack(alignment: .leading, spacing: 14) {

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
                .padding(.top, isKeyboardVisible ? 0 : 24)

                // Give vertical room for centering logic
                .frame(
                    maxHeight: .infinity,
                    alignment: isKeyboardVisible
                        ? .center        // ⬅️ KEY CHANGE: optical centering when keyboard is open
                        : .top
                )
                .offset(y: isKeyboardVisible ? -180 : 0)


                // Reserve space so bottom bar never overlaps content
                Spacer(minLength: bottomBarHeight + 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // ============================
            // BOTTOM BAR (KEYBOARD-AWARE)
            // ============================
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
                    bottomBarHeight = size.height + 16
                }
            }
            .padding(.bottom, keyboardHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard, edges: .all)

        // ============================
        // KEYBOARD TRACKING
        // ============================
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            keyboardHeight = Self.keyboardOverlapHeight(from: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    // ============================
    // HEADER (INSTANT HIDE)
    // ============================
    private var topContent: some View {
        VStack(spacing: 10) {

            if !isKeyboardVisible {
                Image("FullLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 110)
            }

            if !isKeyboardVisible {
                Text("Enter your phone number to continue.")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // ============================
    // KEYBOARD OVERLAP CALC
    // ============================
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
        let covered = max(0, screenHeight - endFrame.minY)

        return max(0, covered - safeBottom)
    }
}

// ============================
// SIZE READER
// ============================
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
