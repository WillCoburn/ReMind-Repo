import SwiftUI

enum OnboardingLayout {
    static let maxContentWidth: CGFloat = 460
    static let maxTourTextWidth: CGFloat = 350

    static func pageHorizontal(for width: CGFloat) -> CGFloat {
        width <= 380 ? 24 : 28
    }

    static func formHorizontal(for width: CGFloat) -> CGFloat {
        width <= 380 ? 28 : 32
    }

    static func contentWidth(in width: CGFloat, horizontalPadding: CGFloat) -> CGFloat {
        max(0, min(maxContentWidth, width - horizontalPadding * 2))
    }
}
