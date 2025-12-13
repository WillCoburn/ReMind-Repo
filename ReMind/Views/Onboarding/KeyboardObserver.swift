// ============================
// File: Views/Onboarding/KeyboardObserver.swift
// ============================
import SwiftUI
import UIKit

/// Shared keyboard observer that reports the keyboard's end frame and animation data so
/// SwiftUI can deterministically lift content relative to its own container.
final class KeyboardObserver: ObservableObject {
    struct AnimationContext {
        let duration: Double
        let curve: UIView.AnimationCurve
    }

    @Published private(set) var endFrame: CGRect = .zero
    @Published private(set) var animationContext: AnimationContext = .init(duration: 0.25, curve: .easeOut)

    var isVisible: Bool { !endFrame.isEmpty && endFrame.minY < UIScreen.main.bounds.height }

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

            withAnimation(.easeOut(duration: duration)) {
                self.endFrame = endFrame
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
                self.endFrame = .zero
                self.animationContext = .init(duration: duration, curve: .easeOut)
            }
        }
    }

    deinit {
        if let willChange { NotificationCenter.default.removeObserver(willChange) }
        if let willHide { NotificationCenter.default.removeObserver(willHide) }
    }

    /// Returns the overlap height between the keyboard and the container represented by the
    /// passed geometry, in that container's coordinate space.
    func height(in geometry: GeometryProxy) -> CGFloat {
        guard isVisible else { return 0 }
        let containerFrame = geometry.frame(in: .global)
        let overlap = containerFrame.maxY - endFrame.minY
        return max(0, overlap)
    }
}
