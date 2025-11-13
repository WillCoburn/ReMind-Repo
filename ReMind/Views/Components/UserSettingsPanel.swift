// =====================================
// File: Views/Settings/UserSettingsPanel.swift
// =====================================
import SwiftUI
import PhotosUI
import MessageUI
import StoreKit



struct UserSettingsPanel: View {
    @EnvironmentObject private var appVM: AppViewModel
    @ObservedObject private var revenueCat = RevenueCatManager.shared

    @Binding var remindersPerDay: Double
    @Binding var tzIdentifier: String
    @Binding var quietStartHour: Double
    @Binding var quietEndHour: Double
    @Binding var bgImageBase64: String

    var onClose: () -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var loadError: String?

    // Mail compose state
    @State private var showMailSheet = false
    @State private var mailError: String?

    // Paywall state
    @State private var showPaywall = false
    @State private var restoreMessage: String?

    // Updated range constants
    private let minReminders: Double = 0.1
    private let maxReminders: Double = 5.0
    private let stepReminders: Double = 0.1

    private let usTimeZones: [String] = {
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
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // 0.1–5.0/day slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Reminders per day")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(remindersDisplay(remindersPerDay)) / day")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $remindersPerDay,
                               in: minReminders...maxReminders,
                               step: stepReminders)

                        Text("Choose how many reminders to receive each day (in tenths). For example, 0.1 = about once every 10 days.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Time zone picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Zone")
                            .font(.subheadline.weight(.semibold))

                        Picker("Time Zone", selection: $tzIdentifier) {
                            ForEach(usTimeZones, id: \.self) { id in
                                Text(prettyTimeZone(id)).tag(id)
                            }
                        }
                        .pickerStyle(.wheel)

                        Text("Used for scheduling sends at the right local time.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }

                    Divider()

                    // Send window
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Send Window")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(hourLabel(quietStartHour)) – \(hourLabel(quietEndHour))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            HStack {
                                Text("Earliest")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Slider(value: Binding(
                                    get: { quietStartHour },
                                    set: { quietStartHour = min($0, quietEndHour) }
                                ), in: 0...23, step: 1)
                                Text(hourLabel(quietStartHour))
                                    .font(.footnote.monospaced())
                                    .frame(width: 44)
                            }
                            HStack {
                                Text("Latest")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Slider(value: Binding(
                                    get: { quietEndHour },
                                    set: { quietEndHour = max($0, quietStartHour) }
                                ), in: 0...23, step: 1)
                                Text(hourLabel(quietEndHour))
                                    .font(.footnote.monospaced())
                                    .frame(width: 44)
                            }
                        }

                        Text("Reminders will be scheduled only between these hours.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Background selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 12) {
                            if let preview = previewImage() {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(.secondary.opacity(0.3), lineWidth: 1))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.secondary.opacity(0.08))
                                    Image(systemName: "photo")
                                        .imageScale(.large)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 72, height: 72)
                            }

                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("Choose Photo", systemImage: "photo.on.rectangle")
                            }
                            .onChange(of: photoItem) { newItem in
                                Task { await importPhoto(newItem) }
                            }

                            if !bgImageBase64.isEmpty {
                                Button(role: .destructive) {
                                    bgImageBase64 = ""
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }

                        if let loadError {
                            Text(loadError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Text("Pick a photo to personalize your app background.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // 📨 Contact Support
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Feedback & Support")
                            .font(.subheadline.weight(.semibold))

                        Text("Have feedback, questions, or concerns?")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            openSupport()
                        } label: {
                            Label("Contact Us", systemImage: "envelope.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.accentColor)
                        }

                        if let mailError {
                            Text(mailError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Divider()

                    // 💳 Subscription section
                    VStack(alignment: .leading, spacing: 8) {
                        let isSubscribed = revenueCat.entitlementActive

                                                if !isSubscribed {
                                                    if let end = appVM.user?.trialEndsAt {
                                                        let dateString = DateFormatter.localizedString(
                                                            from: end,
                                                            dateStyle: .medium,
                                                            timeStyle: .short
                                                        )
                                                        Text("Free trial ends: \(dateString)")
                                                            .font(.footnote)
                                                            .foregroundStyle(.secondary)
                                                    }

                                                    Button("Start Subscription (99¢/mo)") { showPaywall = true }
                                                        .buttonStyle(.borderedProminent)
                                                }

                        Button("Manage Subscription") {
                            if let url = RevenueCatManager.shared.managementURL {
                                UIApplication.shared.open(url)
                            } else if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Restore Purchases") {
                            RevenueCatManager.shared.restore { ok, err in
                                restoreMessage = err ?? (ok ? "Restored." : "Nothing to restore.")
                            }
                        }
                        .buttonStyle(.bordered)

                        if let msg = restoreMessage {
                            Text(msg).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                    .sheet(isPresented: $showPaywall) { SubscriptionSheet() }

                    Spacer(minLength: 8)
                }
                .padding(16)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20, y: 8)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(.clear)
        .padding(.top, 8)
        .sheet(isPresented: $showMailSheet) {
            MailView(
                recipients: ["remindapphelp@gmail.com"],
                subject: "Re[Mind] Feedback"
            )
        }
        .onAppear {
            RevenueCatManager.shared.recomputeAndPersistActive()

            // 🧪 Test StoreKit directly
            Task {
                do {
                    let products = try await Product.products(for: ["remind.monthly.099.us"])
                    print("🧪 SK2 products:", products.map { "\($0.id) • \($0.displayName) • \($0.displayPrice)" })
                } catch {
                    print("🧪 SK2 fetch error:", error.localizedDescription)
                }
            }
        }

    }

    // MARK: - Helpers (support + image import) — unchanged
    private func openSupport() { /* same as your version */
        mailError = nil
        if MFMailComposeViewController.canSendMail() {
            showMailSheet = true
            return
        }
        let addr = "remindapphelp@gmail.com"
        let subject = "Re[Mind] Feedback"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Feedback"
        if let url = URL(string: "mailto:\(addr)?subject=\(encodedSubject)") {
            UIApplication.shared.open(url) { success in
                if !success { mailError = "Couldn’t open Mail. Please email us at \(addr)." }
            }
        } else {
            mailError = "Couldn’t create email link. Please email us at \(addr)."
        }
    }

    private func remindersDisplay(_ value: Double) -> String { String(format: "%.1f", value) }

    private func hourLabel(_ value: Double) -> String {
        let h = Int(round(value)) % 24
        let ampm = h >= 12 ? "PM" : "AM"
        let hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(hour12)\u{00A0}\(ampm)"
    }

    private func prettyTimeZone(_ id: String) -> String {
        if let tz = TimeZone(identifier: id) {
            let seconds = tz.secondsFromGMT()
            let hours = seconds / 3600
            let minutes = abs((seconds % 3600) / 60)
            let sign = hours >= 0 ? "+" : "-"
            return "GMT\(sign)\(abs(hours)):\(String(format: "%02d", minutes)) – \(id)"
        }
        return id
    }

    private func previewImage() -> UIImage? {
        guard !bgImageBase64.isEmpty, let data = Data(base64Encoded: bgImageBase64) else { return nil }
        return UIImage(data: data)
    }

    private func importPhoto(_ item: PhotosPickerItem?) async {
        loadError = nil
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if let img = UIImage(data: data) {
                    let resized = img.resized(maxDimension: 2000)
                    if let jpeg = resized.jpegData(compressionQuality: 0.85) {
                        bgImageBase64 = jpeg.base64EncodedString()
                    } else {
                        bgImageBase64 = data.base64EncodedString()
                    }
                } else {
                    bgImageBase64 = data.base64EncodedString()
                }
            }
        } catch {
            loadError = "Couldn't load photo. Please try a different image."
        }
    }
}

// MARK: - Mail bridge + UIImage resize (unchanged from your version)
private struct MailView: UIViewControllerRepresentable {
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

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
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
