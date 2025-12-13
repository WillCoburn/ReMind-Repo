// ============================
// File: Views/Onboarding/KeyboardObserver.swift
// ============================
import SwiftUI
import UIKit

/// Shared keyboard observer that reports the keyboard's end frame
/// along with animation timing, so SwiftUI views can lift content above the keyboard in sync.
final class KeyboardObserver: ObservableObject {
    struct AnimationContext {
        let duration: Double
        let curve: UIView.AnimationCurve
    }

    /// Keyboard frame in screen coordinates (zero when hidden)
        @Published private(set) var endFrame: CGRect = .zero
    @Published var animationContext: AnimationContext = .init(duration: 0.25, curve: .easeOut)

    var isVisible: Bool { endFrame.height > 0 }

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

            self.endFrame = endFrame
                        self.animationContext = .init(duration: duration, curve: curve)
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

    /// Returns the overlap between the keyboard and the provided geometry container
     /// converted into the container's coordinate space.
     func overlap(in geo: GeometryProxy) -> CGFloat {
         guard isVisible else { return 0 }

         let containerFrame = geo.frame(in: .global)
         let overlap = containerFrame.maxY - endFrame.minY
         let adjusted = overlap - geo.safeAreaInsets.bottom

         return max(0, adjusted)
     }
    
    deinit {
        if let willChange { NotificationCenter.default.removeObserver(willChange) }
        if let willHide { NotificationCenter.default.removeObserver(willHide) }
    }
}
