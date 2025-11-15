// ===========================================
// File: Views/Settings/SettingsHelpers.swift
// ===========================================
import SwiftUI
import MessageUI

enum SettingsHelpers {
    static func remindersDisplay(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    static func hourLabel(_ value: Double) -> String {
        let h = Int(round(value)) % 24
        let ampm = h >= 12 ? "PM" : "AM"
        let hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(hour12)\u{00A0}\(ampm)"
    }

    static func prettyTimeZone(_ id: String) -> String {
        if let tz = TimeZone(identifier: id) {
            let seconds = tz.secondsFromGMT()
            let hours = seconds / 3600
            let minutes = abs((seconds % 3600) / 60)
            let sign = hours >= 0 ? "+" : "-"
            return "GMT\(sign)\(abs(hours)):\(String(format: "%02d", minutes)) – \(id)"
        }
        return id
    }

    static func usTimeZones() -> [String] {
        var ids = TimeZone.knownTimeZoneIdentifiers.filter {
            $0.hasPrefix("US/") || $0.hasPrefix("America/")
        }
        let preferred = [
            "America/New_York", "America/Chicago", "America/Denver", "America/Phoenix",
            "America/Los_Angeles", "America/Anchorage", "America/Adak", "Pacific/Honolulu"
        ]
        let preferredSet = Set(preferred)
        let others = ids.filter { !preferredSet.contains($0) }.sorted()
        ids = preferred + others
        var seen = Set<String>(); return ids.filter { seen.insert($0).inserted }
    }

    static func previewImage(fromBase64 b64: String) -> UIImage? {
        guard !b64.isEmpty, let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Mail bridge
struct MailView: UIViewControllerRepresentable {
    var recipients: [String]
    var subject: String
    var body: String? = nil

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        if let body { vc.setMessageBody(body, isHTML: false) }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - UIImage resize helper
extension UIImage {
    func remind_resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
