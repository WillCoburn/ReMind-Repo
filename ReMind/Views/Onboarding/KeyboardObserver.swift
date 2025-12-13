// ============================
// File: Views/Onboarding/KeyboardObserver.swift
// ============================
import SwiftUI
import UIKit

/// Shared keyboard observer that reports the keyboard's end height relative to the screen
/// along with animation timing, so SwiftUI views can lift content above the keyboard in sync.
final class KeyboardObserver: ObservableObject {
    struct AnimationContext {
        let duration: Double
        let curve: UIView.AnimationCurve
    }

    @Published var height: CGFloat = 0
    @Published var animationContext: AnimationContext = .init(duration: 0.25, curve: .easeOut)

    var isVisible: Bool { height > 0 }

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
                let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return }

            let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            let curveRaw = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? UIView.AnimationCurve.easeOut.rawValue
            let curve = UIView.AnimationCurve(rawValue: curveRaw) ?? .easeOut

            let screen = UIScreen.main.bounds
            let overlap = max(0, screen.maxY - endFrame.minY)

            withAnimation(.easeOut(duration: duration)) {
                self.height = overlap
                self.animationContext = .init(duration: duration, curve: curve)
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
                self.height = 0
                self.animationContext = .init(duration: duration, curve: .easeOut)
            }
        }
    }

    deinit {
        if let willChange { NotificationCenter.default.removeObserver(willChange) }
        if let willHide { NotificationCenter.default.removeObserver(willHide) }
    }
}
