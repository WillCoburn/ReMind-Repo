import UIKit

/// Small utility for emitting system haptics.
enum Haptics {
    /// Plays a pleasant success confirmation haptic.
    static func success() {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
}
