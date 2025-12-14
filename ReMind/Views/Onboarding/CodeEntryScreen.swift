// ============================
// File: Views/Onboarding/CodeEntryScreen.swift
// ============================
import SwiftUI
import UIKit

struct CodeEntryScreen: View {
    @Binding var code: String
    let phoneNumber: String

    let errorText: String
    let isVerifying: Bool

    let onBack: () -> Void
    let onResend: () -> Void
    let onVerify: () -> Void

    @State private var keyboardHeight: CGFloat = 0
    @State private var bottomAreaHeight: CGFloat = 0

    // Space we must keep clear at the bottom:
    // - the lifted bottomArea itself
    // - the keyboard overlap
    // - a little gap
    private var reservedBottomSpace: CGFloat {
        bottomAreaHeight + keyboardHeight + 24
    }

    var body: some View {
        ZStack {

            // ✅ Center the code entry UI in the space ABOVE (keyboard + verify area)
            VStack {
                Spacer(minLength: 0)

                CodeEntrySection(
                    code: $code,
                    phoneNumber: phoneNumber,
                    onEditNumber: onBack,
                    onResend: onResend,
                    showTopBar: false   // ✅ back arrow is pinned separately now
                )
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .padding(.bottom, reservedBottomSpace) // ✅ this is what raises/centers it
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: reservedBottomSpace)

            // ✅ Bottom area (error banner + verify button), lifted above keyboard
            VStack {
                Spacer(minLength: 0)

                bottomArea
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .readSize { size in
                        bottomAreaHeight = size.height + 16
                    }
            }
            .padding(.bottom, keyboardHeight)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: keyboardHeight)

            // ✅ Back arrow pinned to top-left, never moves
            topBarPinned
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

    private var topBarPinned: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
            .padding(.leading, 16)
            .padding(.top, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var bottomArea: some View {
        VStack(spacing: 12) {
            if !errorText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(errorText)
                        .font(.callout)
                        .foregroundColor(.red)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.12))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.35), lineWidth: 1)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button(action: onVerify) {
                ZStack {
                    Text(isVerifying ? "Verifying…" : "Verify Code")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .opacity(isVerifying ? 0 : 1)

                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(code.count == 6 ? Color.figmaBlue : Color.gray.opacity(0.35))
                .cornerRadius(14)
            }
            .disabled(code.count < 6 || isVerifying)
        }
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
