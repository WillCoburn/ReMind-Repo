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

    @Binding var remindersPerWeek: Double
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
    private let minReminders: Double = 0
    private let maxReminders: Double = 20
    private let stepReminders: Double = 1

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

    private var sendWindowBinding: Binding<ClosedRange<Double>> {
        Binding(
            get: { quietStartHour...quietEndHour },
            set: { range in
                quietStartHour = range.lowerBound
                quietEndHour = range.upperBound
            }
        )
    }

    
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

                    // 1-20/week slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Reminders per week")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(remindersDisplay(remindersPerWeek)) / week")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $remindersPerWeek,
                               in: minReminders...maxReminders,
                               step: stepReminders)

                        Text("How many ReMinders do you want to receive each week?")
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
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

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

                        VStack(spacing: 12) {
                            RangeSlider(
                                value: sendWindowBinding,
                                in: 0...23,
                                step: 1,
                                minimumValueLabel: {
                                    Text(hourLabel(0))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                },
                                maximumValueLabel: {
                                    Text(hourLabel(23))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            )

                            
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Start")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(hourLabel(quietStartHour))
                                        .font(.footnote.monospaced())
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("End")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(hourLabel(quietEndHour))
                                        .font(.footnote.monospaced())
                                }
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
                        let willRenew = revenueCat.entitlementWillRenew
                        let expiration = revenueCat.entitlementExpirationDate

                        let now = Date()
                        let trialEnd = appVM.user?.trialEndsAt
                        let onTrial = (trialEnd ?? .distantPast) > now && !isSubscribed

                        // 🔎 State 1: user has an active entitlement (paid access)
                        if isSubscribed {
                            if let expiration {
                                let dateString = DateFormatter.localizedString(
                                    from: expiration,
                                    dateStyle: .medium,
                                    timeStyle: .short
                                )

                                if willRenew {
                                    Text("Subscription renews on: \(dateString)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Subscription ends on: \(dateString)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // In this state we do NOT show the "Start Subscription" button.

                        // 🔎 State 2: no entitlement – user is either on free trial or fully unsubscribed
                        } else {
                            if onTrial, let trialEnd {
                                let dateString = DateFormatter.localizedString(
                                    from: trialEnd,
                                    dateStyle: .medium,
                                    timeStyle: .short
                                )
                                Text("Free trial ends: \(dateString)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Button("Start Subscription") {
                                showPaywall = true
                            }
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
                            Text(msg)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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
            RevenueCatManager.shared.refreshEntitlementState()
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
    private func openSupport() {
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

    private func remindersDisplay(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

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
        guard !bgImageBase64.isEmpty,
              let data = Data(base64Encoded: bgImageBase64) else { return nil }
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

    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: Context) {}

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







// MARK: - Range Slider (Dual-handle)

private struct RangeSlider<MinimumLabel: View, MaximumLabel: View>: View {
    @Binding var value: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    var step: Double
    @ViewBuilder var minimumValueLabel: () -> MinimumLabel
    @ViewBuilder var maximumValueLabel: () -> MaximumLabel

    private let handleDiameter: CGFloat = 28
    private let trackHeight: CGFloat = 4

    init(value: Binding<ClosedRange<Double>>, in bounds: ClosedRange<Double>, step: Double = 1,
         @ViewBuilder minimumValueLabel: @escaping () -> MinimumLabel,
         @ViewBuilder maximumValueLabel: @escaping () -> MaximumLabel) {
        _value = value
        self.bounds = bounds
        self.step = step
        self.minimumValueLabel = minimumValueLabel
        self.maximumValueLabel = maximumValueLabel
    }

    private var totalSpan: Double { max(bounds.upperBound - bounds.lowerBound, .leastNonzeroMagnitude) }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let usableWidth = max(totalWidth - handleDiameter, 1)
                let lowerPosition = position(for: value.lowerBound, totalWidth: totalWidth)
                let upperPosition = position(for: value.upperBound, totalWidth: totalWidth)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: usableWidth, height: trackHeight)
                        .position(x: totalWidth / 2, y: handleDiameter / 2)

                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Color.accentColor)
                        .frame(width: max(upperPosition - lowerPosition, 0), height: trackHeight)
                        .position(x: lowerPosition + max((upperPosition - lowerPosition) / 2, 0),
                                  y: handleDiameter / 2)

                    sliderHandle
                        .position(x: lowerPosition, y: handleDiameter / 2)
                        .highPriorityGesture(dragGesture(forLowerHandleIn: totalWidth))

                    sliderHandle
                        .position(x: upperPosition, y: handleDiameter / 2)
                        .highPriorityGesture(dragGesture(forUpperHandleIn: totalWidth))
                }
                .frame(height: handleDiameter)
            }
            .frame(height: handleDiameter)

            HStack {
                minimumValueLabel()
                Spacer()
                maximumValueLabel()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Range")
        .accessibilityValue("\(Int(value.lowerBound)) to \(Int(value.upperBound))")
    }

    private var sliderHandle: some View {
        Circle()
            .fill(Color(uiColor: .systemBackground))
            .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            .shadow(radius: 1, y: 1)
            .frame(width: handleDiameter, height: handleDiameter)
    }

    private func percent(for rawValue: Double) -> CGFloat {
        let clamped = min(max(rawValue, bounds.lowerBound), bounds.upperBound)
        return CGFloat((clamped - bounds.lowerBound) / totalSpan)
    }

    private func position(for value: Double, totalWidth: CGFloat) -> CGFloat {
        let usableWidth = max(totalWidth - handleDiameter, 1)
        return percent(for: value) * usableWidth + handleDiameter / 2
    }

    private func dragGesture(forLowerHandleIn totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let newValue = value(for: gesture.location.x, totalWidth: totalWidth)
                let limited = min(newValue, value.upperBound)
                value = limited...value.upperBound
            }
    }

    private func dragGesture(forUpperHandleIn totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let newValue = value(for: gesture.location.x, totalWidth: totalWidth)
                let limited = max(newValue, value.lowerBound)
                value = value.lowerBound...limited
            }
    }

    private func value(for location: CGFloat, totalWidth: CGFloat) -> Double {
        let usableWidth = max(totalWidth - handleDiameter, 1)
        let clampedLocation = min(max(location, handleDiameter / 2), totalWidth - handleDiameter / 2)
        let percent = Double((clampedLocation - handleDiameter / 2) / usableWidth)
        let rawValue = bounds.lowerBound + percent * totalSpan
        let snapped = snap(rawValue)
        return min(max(snapped, bounds.lowerBound), bounds.upperBound)
    }

    private func snap(_ rawValue: Double) -> Double {
        guard step > 0 else { return rawValue }
        let relative = (rawValue - bounds.lowerBound) / step
        let rounded = relative.rounded()
        return bounds.lowerBound + rounded * step
    }
}

private extension RangeSlider where MinimumLabel == EmptyView, MaximumLabel == EmptyView {
    init(value: Binding<ClosedRange<Double>>, in bounds: ClosedRange<Double>, step: Double = 1) {
        self.init(
            value: value,
            in: bounds,
            step: step,
            minimumValueLabel: { EmptyView() },
            maximumValueLabel: { EmptyView() }
        )
    }
}
