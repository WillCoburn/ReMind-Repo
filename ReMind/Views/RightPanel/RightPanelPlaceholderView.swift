import MessageUI
import PhotosUI
import SafariServices
import StoreKit
import SwiftUI

struct RightPanelPlaceholderView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @ObservedObject private var revenueCat = RevenueCatManager.shared

    @State private var showPaywall = false

    @AppStorage("remindersPerWeek") private var remindersPerWeek: Double = 3.0 // 1...20
    @AppStorage("tzIdentifier")    private var tzIdentifier: String = TimeZone.current.identifier
    @AppStorage("quietStartHour")  private var quietStartHour: Double = 9     // 0...24
    @AppStorage("quietEndHour")    private var quietEndHour: Double = 22      // 0...24
    @AppStorage("bgImageBase64")   private var bgImageBase64: String = ""

    @State private var photoItem: PhotosPickerItem?
    @State private var loadError: String?
    @State private var pendingSaveWorkItem: DispatchWorkItem?
    @State private var activeSheet: ActiveSettingsSheet?
    @State private var showDeleteSheet = false
    @State private var restoreMessage: String?
    @State private var mailError: String?
    @State private var showCommunityGuidelines = false
    @State private var showFreeLimitsWhy = false

    var body: some View {
        ZStack {
            // 👇 Light brand-tinted background
            Color.white.ignoresSafeArea()
            Color.blue.opacity(0.04).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header text (replaces toolbar title)
                    Text("Stats & Settings")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 36)      // ↑ more space from the very top
                        .padding(.bottom, 20)   // ↑ space before the tiles

                    // MARK: - Top stat tiles
                    LazyVGrid(columns: statsColumns, spacing: 12) {
                        savedTile
                        streakTile
                        receivedTile
                    }
                    .padding(.top, 4)

                    settingsList
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .reminders:
                RemindersPerWeekSheet(
                    remindersPerWeek: $remindersPerWeek,
                    onChange: persistSettingsDebounced,
                    onDone: { activeSheet = nil; persistSettingsDebounced() }
                )
            case .sendWindow:
                SendWindowSheet(
                    startHour: $quietStartHour,
                    endHour: $quietEndHour,
                    onChange: persistSettingsDebounced,
                    onDone: { activeSheet = nil; persistSettingsDebounced() }
                )
            case .timeZone:
                TimeZoneSheet(
                    tzIdentifier: $tzIdentifier,
                    onChange: persistSettingsDebounced,
                    onDone: { activeSheet = nil; persistSettingsDebounced() }
                )
            case .background:
                BackgroundPickerSheet(
                    photoItem: $photoItem,
                    bgImageBase64: $bgImageBase64,
                    loadError: $loadError,
                    onChange: persistSettingsDebounced,
                    onDone: { activeSheet = nil; persistSettingsDebounced() }
                )
            case .subscription:
                SubscriptionOptionsSheet(
                    appVM: appVM,
                    onStartSubscription: {
                        activeSheet = nil
                        RevenueCatManager.shared.forceIdentify { showPaywall = true }
                    },
                    restoreMessage: $restoreMessage
                )
            case .contactUs:
                ContactUsMailSheet()
            }
        }
        .sheet(isPresented: $showDeleteSheet) {
            DeleteAccountSheet(isPresented: $showDeleteSheet)
                .environmentObject(appVM)
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionSheet()
        }
        .sheet(isPresented: $showCommunityGuidelines) {
            SafariView(url: URL(string: "https://re-mind-app.github.io/remind-site/")!)
        }
        .alert(
            "Mail Error",
            isPresented: Binding(
                get: { mailError != nil },
                set: { if !$0 { mailError = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) { mailError = nil }
            },
            message: {
                Text(mailError ?? "")
            }
        )
        .alert("Why the limits?", isPresented: $showFreeLimitsWhy) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("I'm very sorry to have to limit your experience :( But using a toll-free number costs money every time a text is sent, so I'm running a loss on free users and have to put up some guardrails.")
        }
        .onAppear {
            //no rc calls

            Task {
                do {
                    let products = try await Product.products(for: ["remind.monthly.099.us"])
                    print("🧪 SK2 products:", products.map { "\($0.id) • \($0.displayName) • \($0.displayPrice)" })
                } catch {
                    print("🧪 SK2 fetch error:", error.localizedDescription)
                }
            }
        }
        // Hide the nav bar so the custom layout can use the full vertical space.
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(.xSmall ... .xxLarge)
    }

    private var statsColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
            count: 3
        )
    }

    // MARK: - Settings list

    private var settingsList: some View {
        VStack(spacing: 12) {
            if !appVM.isProUser {
                freeLimitsBanner
            }

            automaticSettingsSection
            experienceSection
            accountSection
        }
    }

    private var freeLimitsBanner: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                freeLimitsText
                Spacer(minLength: 8)
                freeLimitsButtons
            }

            VStack(alignment: .leading, spacing: 10) {
                freeLimitsText
                freeLimitsButtons
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.20))
        )
    }

    private var freeLimitsText: some View {
        Text("Free users limited to 3 random reminders a week")
            .font(.footnote.weight(.semibold))
            .foregroundColor(.black.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freeLimitsButtons: some View {
        HStack(spacing: 8) {
            Button("Why?") {
                showFreeLimitsWhy = true
            }
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.7))
            .foregroundColor(.black.opacity(0.8))
            .clipShape(Capsule())

            Button("Upgrade") {
                RevenueCatManager.shared.forceIdentify {
                    showPaywall = true
                }
            }
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.figmaBlue)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundColor(.figmaBlue)
            .padding(.horizontal, 20)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    private var automaticSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsSectionHeader("Automatic Reminder Settings")

            VStack(spacing: 0) {
                SettingsRow(
                    title: "Automated Reminders Per Week",
                    value: "\(SettingsHelpers.remindersDisplay(remindersPerWeek))",
                    isDestructive: false,
                    action: { activeSheet = .reminders }
                )

                SettingsRow(
                    title: "Message Window",
                    value: "\(SettingsHelpers.hourLabel(quietStartHour)) - \(SettingsHelpers.hourLabel(quietEndHour))",
                    isDestructive: false,
                    action: { activeSheet = .sendWindow }
                )

                SettingsRow(
                    title: "Time Zone",
                    value: SettingsHelpers.prettyTimeZone(tzIdentifier),
                    isDestructive: false,
                    action: { activeSheet = .timeZone }
                )
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var experienceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsSectionHeader("My Experience")

            VStack(spacing: 0) {
                SettingsRow(
                    title: "Subscription",
                    value: nil,
                    isDestructive: false,
                    action: { activeSheet = .subscription }
                )

                SettingsRow(
                    title: "Personalize Background",
                    value: nil,
                    isDestructive: false,
                    action: { activeSheet = .background }
                )
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsSectionHeader("Account")

            VStack(spacing: 0) {
                SettingsRow(
                    title: "Contact Us",
                    value: nil,
                    isDestructive: false,
                    action: openSupport
                )

                SettingsRow(
                    title: "Community Guidelines",
                    value: nil,
                    isDestructive: false,
                    action: { showCommunityGuidelines = true }
                )

                SettingsRow(
                    title: "Log Out",
                    value: nil,
                    isDestructive: true,
                    showsChevron: false,
                    action: { appVM.logout() }
                )

                Color.clear.frame(height: 6)

                SettingsRow(
                    title: "Delete Account",
                    value: nil,
                    isDestructive: true,
                    showsChevron: false,
                    action: { showDeleteSheet = true }
                )
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Mail

    private func openSupport() {
        mailError = nil

        if MFMailComposeViewController.canSendMail() {
            activeSheet = .contactUs
            return
        }

        let addr = "remindapphelp@gmail.com"
        let subject = "Re[Mind] Feedback"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Feedback"

        if let url = URL(string: "mailto:\(addr)?subject=\(encodedSubject)") {
            UIApplication.shared.open(url) { success in
                if !success {
                    mailError = "Couldn’t open Mail. Please email us at \(addr)."
                }
            }
        } else {
            mailError = "Couldn’t create email link. Please email us at \(addr)."
        }
    }

    // MARK: - Settings sync

    @State private var saveTask: Task<Void, Never>?

    private func persistSettingsDebounced() {
        saveTask?.cancel()

        saveTask = Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s debounce

            do {
                print("🧪 committing settings batch")
                try await UserSettingsSync.pushAndApply()
                print("✅ pushAndApply (right panel) OK")
            } catch {
                print("❌ pushAndApply (right panel) failed:", error.localizedDescription)
            }
        }
    }

}

// MARK: - Active sheet enum

enum ActiveSettingsSheet: Identifiable {
    case reminders
    case sendWindow
    case timeZone
    case background
    case subscription
    case contactUs

    var id: Int { hashValue }
}

// MARK: - Preview

struct RightPanelPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        RightPanelPlaceholderView()
            .environmentObject(AppViewModel())
    }
}

// MARK: - Tiles (Figma-style cards)

private extension RightPanelPlaceholderView {

    // Saved (left)
    var savedTile: some View {
        statTile(
            systemImage: "tray.full.fill",
            title: "Saved",
            value: "\(appVM.entries.count)"
        )
    }

    // Entry Streak (middle)
    var streakTile: some View {
        statTile(
            systemImage: "flame.fill",
            title: "Entry Streak",
            value: "\(appVM.streakCount)", suffix: "days"
        )
    }

    // Received (right)
    var receivedTile: some View {
        statTile(
            systemImage: "bubble.left.and.bubble.right.fill",
            title: "Received",
            value: "\(appVM.user?.receivedCount ?? 0)"
        )
    }

    // Shared card style
    func statTile(systemImage: String, title: String, value: String, suffix: String? = nil) -> some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.figmaBlue)
                .frame(height: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.figmaBlue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(height: 34, alignment: .center)

        }
        .frame(maxWidth: .infinity, minHeight: 128, maxHeight: 128)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .dynamicTypeSize(.xSmall ... .xLarge)
    }
}

// MARK: - SettingsRow

struct SettingsRow: View {
    let title: String
    let value: String?
    let isDestructive: Bool
    var showsChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                horizontalContent
                verticalContent
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.gray.opacity(0.25)),
                alignment: .bottom
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var horizontalContent: some View {
        HStack(alignment: .center, spacing: 12) {
            titleText
                .frame(maxWidth: .infinity, alignment: .leading)

            trailingContent
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleText

            trailingContent
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleText: some View {
        Text(title)
            .foregroundColor(isDestructive ? .red : .black)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var trailingContent: some View {
        HStack(spacing: 8) {
            if let value = value {
                Text(value)
                    .foregroundColor(isDestructive ? .red : .figmaBlue)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(white: 0.45))
                    .font(.footnote.weight(.semibold))
                    .frame(width: 14)
            }
        }
    }
}


struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Sheets (unchanged structurally)

struct RemindersPerWeekSheet: View {
    @EnvironmentObject private var appVM: AppViewModel
    @Binding var remindersPerWeek: Double

    var onChange: () -> Void
    var onDone: () -> Void

    private let minReminders: Double = 1
    private let freeMaxReminders: Double = 3
    private let maxReminders: Double = 20
    private let stepReminders: Double = 1

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 44, height: 6)
                .padding(.top, 8)

            Text("Automated Reminders Per Week")
                .font(.headline)

            if appVM.isProUser {
                Slider(
                    value: $remindersPerWeek,
                    in: minReminders...maxReminders,
                    step: stepReminders
                )
                .onChange(of: remindersPerWeek) { _ in onChange() }
            } else {
                Slider(
                    value: Binding(
                        get: { min(max(remindersPerWeek, minReminders), freeMaxReminders) },
                        set: { remindersPerWeek = min(max($0, minReminders), freeMaxReminders) }
                    ),
                    in: minReminders...freeMaxReminders,
                    step: stepReminders
                )
                .onChange(of: remindersPerWeek) { _ in onChange() }

                Text("Upgrade to access up to 20 reminders/week!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(SettingsHelpers.remindersDisplay(remindersPerWeek)) reminders")
                .font(.subheadline)
                .foregroundColor(.figmaBlue)

            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .tint(.figmaBlue)
                .padding(.bottom, 12)
        }
        .padding()
        .presentationDetents([.medium])
    }
}

struct SendWindowSheet: View {
    @Binding var startHour: Double
    @Binding var endHour: Double

    var onChange: () -> Void
    var onDone: () -> Void

    private var binding: Binding<ClosedRange<Double>> {
        Binding(
            get: { startHour ... endHour },
            set: { r in
                startHour = max(0, min(24, r.lowerBound))
                endHour = max(0, min(24, r.upperBound))
            }
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 44, height: 6)
                .padding(.top, 8)

            Text("Automated Send window")
                .font(.headline)

            Text("\(SettingsHelpers.hourLabel(startHour)) – \(SettingsHelpers.hourLabel(endHour))")
                .font(.subheadline)
                .foregroundColor(.figmaBlue)

            RangeSlider(
                value: binding,
                in: 0.0...24.0,
                step: 1.0
            )
            .onChange(of: startHour) { _ in onChange() }
            .onChange(of: endHour) { _ in onChange() }

            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .tint(.figmaBlue)
                .padding(.bottom, 12)
        }
        .padding()
        .presentationDetents([.medium])
    }
}

struct TimeZoneSheet: View {
    @Binding var tzIdentifier: String

    var onChange: () -> Void
    var onDone: () -> Void

    private let usTimeZones = SettingsHelpers.usTimeZones()

    var body: some View {
        NavigationStack {
            List(usTimeZones, id: \.self) { id in
                Button {
                    tzIdentifier = id
                    onChange()
                } label: {
                    HStack {
                        Text(SettingsHelpers.prettyTimeZone(id))
                            .foregroundColor(.primary)
                        Spacer()
                        if id == tzIdentifier {
                            Image(systemName: "checkmark")
                                .foregroundColor(.figmaBlue)
                        }
                    }
                }
            }
            .navigationTitle("Time Zone")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                        .foregroundColor(.figmaBlue)
                }
            }
        }
    }
}

struct BackgroundPickerSheet: View {
    @Binding var photoItem: PhotosPickerItem?
    @Binding var bgImageBase64: String
    @Binding var loadError: String?

    var onChange: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 44, height: 6)
                .padding(.top, 8)

            Text("Personalize Background")
                .font(.headline)

            BackgroundPickerSection(
                photoItem: $photoItem,
                bgImageBase64: $bgImageBase64,
                loadError: $loadError
            )
            .onChange(of: bgImageBase64) { _ in onChange() }

            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .tint(.figmaBlue)
                .padding(.bottom, 12)
        }
        .padding()
        .presentationDetents([.medium])
    }
}

struct SubscriptionOptionsSheet: View {
    var appVM: AppViewModel
    @ObservedObject var revenueCat: RevenueCatManager = .shared

    var onStartSubscription: () -> Void
    @Binding var restoreMessage: String?

    init(appVM: AppViewModel, onStartSubscription: @escaping () -> Void, restoreMessage: Binding<String?>) {
        self.appVM = appVM
        self.onStartSubscription = onStartSubscription
        self._restoreMessage = restoreMessage
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 44, height: 6)
                .padding(.top, 8)
            
            Text("Subscription Status: \(revenueCat.entitlementActive ? "Subscribed" : "Unsubscribed")")
                .font(.headline)
                .frame(maxWidth: .infinity)

            SubscriptionSection(
                appVM: appVM,
                revenueCat: revenueCat,
                onStartSubscription: onStartSubscription,
                restoreMessage: $restoreMessage
            )
            .frame(maxWidth: .infinity)

            Spacer(minLength: 8)
        }
        .padding()
        .multilineTextAlignment(.center)
                .presentationDetents([.medium])
    }
}

struct ContactUsMailSheet: View {
    var body: some View {
        MailView(
            recipients: ["remindapphelp@gmail.com"],
            subject: "Re[Mind] Feedback"
        )
    }
}
