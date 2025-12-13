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

    @StateObject private var keyboard = KeyboardOverlapObserver()

    var body: some View {
        GeometryReader { geo in
            let safeBottom = geo.safeAreaInsets.bottom
            let lift = max(0, keyboard.overlapHeight - safeBottom)

            ZStack(alignment: .bottom) {

                // ===== MAIN CONTENT (never gets auto-pushed) =====
                VStack(spacing: 0) {

                    VStack(spacing: keyboard.isVisible ? 6 : 12) {
                        Image("FullLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 300, height: keyboard.isVisible ? 80 : 120)
                            .padding(.top, keyboard.isVisible ? 10 : 26)

                        if !keyboard.isVisible {
                            Text("Enter your phone number to continue.")
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.top, 2)
                                .transition(.opacity)
                        }
                    }

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
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, keyboard.isVisible ? 12 : 22)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // ===== BOTTOM PINNED (lifted above keyboard) =====
                ConsentAndAgreeBottom(
                    hasConsented: $hasConsented,
                    consentMessage: consentMessage,
                    canContinue: canContinue,
                    isSending: isSending,
                    onAgreeAndContinue: onContinue
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 12 + lift) // ✅ sits right above keyboard
            }
            // ✅ Prevent iOS from “helpfully” pushing views around for the keyboard
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .animation(.easeInOut(duration: 0.22), value: keyboard.isVisible)
        }
    }
}

/// Measures how much the keyboard overlaps the screen (robust across devices)
final class KeyboardOverlapObserver: ObservableObject {
    @Published var overlapHeight: CGFloat = 0
    var isVisible: Bool { overlapHeight > 0 }

    private var willChange: NSObjectProtocol?
    private var willHide: NSObjectProtocol?

    init() {
        willChange = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self else { return }
            guard
                let info = notif.userInfo,
                let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            else { return }

            let screen = UIScreen.main.bounds
            let overlap = max(0, screen.maxY - endFrame.minY)

            withAnimation(.easeOut(duration: duration)) {
                self.overlapHeight = overlap
            }
        }

        willHide = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self else { return }
            let duration = (notif.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            withAnimation(.easeOut(duration: duration)) {
                self.overlapHeight = 0
            }
        }
    }

    deinit {
        if let willChange { NotificationCenter.default.removeObserver(willChange) }
        if let willHide { NotificationCenter.default.removeObserver(willHide) }
    }
}
