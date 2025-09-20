// Utils/Haptics.swift
import UIKit

enum Haptics {
    static func success() {
        #if !targetEnvironment(simulator)
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.success)
        #endif
    }

    static func light() {
        #if !targetEnvironment(simulator)
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
        #endif
    }
}
