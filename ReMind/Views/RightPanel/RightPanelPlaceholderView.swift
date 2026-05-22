import MessageUI
import SafariServices
import StoreKit
import SwiftUI

private enum StatsSettingsTextRole {
    case screenTitle
    case statCardLabel
    case statCardValue
    case statCardUnit
    case freeBannerText
    case freeBannerButton
    case sectionHeader
    case settingsRowTitle
    case settingsRowValue

    var font: Font {
        switch self {
        case .screenTitle:
            return .title2.weight(.semibold)
        case .statCardLabel:
            return .callout.weight(.semibold)
        case .statCardValue:
            return .system(.title, design: .rounded).weight(.bold)
        case .statCardUnit:
            return .callout.weight(.semibold)
        case .freeBannerText:
            return .body
        case .freeBannerButton:
            return .caption.weight(.semibold)
        case .sectionHeader:
            return .headline.weight(.bold)
        case .settingsRowTitle:
            return .body
        case .settingsRowValue:
            return .callout.weight(.semibold)
        }
    }

    func maximumDynamicTypeSize(usesAccessibilityLayout: Bool) -> DynamicTypeSize {
        guard usesAccessibilityLayout else {
            switch self {
            case .screenTitle, .statCardValue, .sectionHeader, .settingsRowTitle:
                return .xLarge
            case .statCardLabel, .statCardUnit, .freeBannerButton, .settingsRowValue:
                return .large
            case .freeBannerText:
                return .xLarge
            }
        }

        switch self {
        case .screenTitle, .statCardValue:
            return .accessibility3
        case .freeBannerButton:
            return .accessibility3
        case .statCardLabel, .statCardUnit, .freeBannerText, .sectionHeader, .settingsRowTitle, .settingsRowValue:
            return .accessibility5
        }
    }

    func lineLimit(usesAccessibilityLayout: Bool) -> Int? {
        if usesAccessibilityLayout {
            switch self {
            case .screenTitle, .freeBannerButton:
                return 1
            case .statCardValue, .statCardUnit:
                return 2
            case .statCardLabel, .freeBannerText, .sectionHeader, .settingsRowTitle, .settingsRowValue:
                return nil
            }
        }

        switch self {
        case .statCardLabel:
            return 2
        case .screenTitle, .statCardValue, .statCardUnit, .freeBannerText, .freeBannerButton, .sectionHeader, .settingsRowTitle, .settingsRowValue:
            return 1
        }
    }

    func minimumScaleFactor(usesAccessibilityLayout: Bool) -> CGFloat {
        guard !usesAccessibilityLayout else {
            return 0.92
        }

        switch self {
        case .screenTitle:
            return 0.86
        case .statCardLabel:
            return 0.84
        case .statCardValue:
            return 0.78
        case .statCardUnit:
            return 0.84
        case .settingsRowTitle, .settingsRowValue:
            return 0.86
        case .freeBannerButton, .sectionHeader:
            return 0.88
        case .freeBannerText:
            return 0.86
        }
    }
}

private struct StatsSettingsTextModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let role: StatsSettingsTextRole

    func body(content: Content) -> some View {
        let usesAccessibilityLayout = dynamicTypeSize.brainMailUsesAccessibilityLayout

        content
            .font(role.font)
            .lineLimit(role.lineLimit(usesAccessibilityLayout: usesAccessibilityLayout))
            .minimumScaleFactor(role.minimumScaleFactor(usesAccessibilityLayout: usesAccessibilityLayout))
            .truncationMode(.tail)
            .allowsTightening(true)
            .dynamicTypeSize(.xSmall ... role.maximumDynamicTypeSize(usesAccessibilityLayout: usesAccessibilityLayout))
    }
}

private extension View {
    func statsSettingsText(_ role: StatsSettingsTextRole) -> some View {
        modifier(StatsSettingsTextModifier(role: role))
    }
}

struct RightPanelPlaceholderView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var revenueCat = RevenueCatManager.shared

    @AppStorage("remindersPerWeek") private var remindersPerWeek: Double = 3.0 // 1...14
    @AppStorage("tzIdentifier")    private var tzIdentifier: String = TimeZone.current.identifier
    @AppStorage("quietStartHour")  private var quietStartHour: Double = 9     // 0...24
    @AppStorage("quietEndHour")    private var quietEndHour: Double = 22      // 0...24

    @State private var activeSheet: ActiveSettingsSheet?
    @State private var restoreMessage: String?
    @State private var mailError: String?
    @State private var showFreeLimitsWhy = false
    @State private var settingsSaveSequence: Int64 = 0

    var body: some View {
        ZStack {
            // 👇 Light brand-tinted background
            Color.white.ignoresSafeArea()
            Color.blue.opacity(0.04).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: usesAccessibilityLayout ? 24 : 20) {

                    // Header text (replaces toolbar title)
                    Text("Stats & Settings")
                        .statsSettingsText(.screenTitle)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, usesAccessibilityLayout ? 28 : 36)
                        .padding(.bottom, usesAccessibilityLayout ? 12 : 20)

                    // MARK: - Top stat tiles
                    LazyVGrid(columns: statsColumns, spacing: usesAccessibilityLayout ? 14 : 12) {
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
            case .subscription:
                SubscriptionOptionsSheet(
                    appVM: appVM,
                    onStartSubscription: {
                        RevenueCatManager.shared.forceIdentify(reason: "statsSubscriptionSheetStart") {
                            DispatchQueue.main.async {
                                activeSheet = .paywall
                            }
                        }
                    },
                    restoreMessage: $restoreMessage
                )
            case .contactUs:
                ContactUsMailSheet()
            case .deleteAccount:
                DeleteAccountSheet(
                    isPresented: Binding(
                        get: { activeSheet == .deleteAccount },
                        set: { if !$0 { activeSheet = nil } }
                    )
                )
                .environmentObject(appVM)
            case .paywall:
                SubscriptionSheet()
            case .communityGuidelines:
                SafariView(url: URL(string: "https://re-mind-app.github.io/BrainMail-site/")!)
            }
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
        .overlay {
            if showFreeLimitsWhy {
                FreeLimitsWhyOverlay {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showFreeLimitsWhy = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showFreeLimitsWhy)
        .onAppear {
            appVM.refreshRevenueCatEntitlement(reason: "statsSettingsAppear")
            clampReminderSelectionIfNeeded()
            logSubscriptionUIResolution()

#if DEBUG
            Task {
                do {
                    let products = try await Product.products(for: ["remind.monthly.099.us"])
                    print("🧪 SK2 products:", products.map { "\($0.id) • \($0.displayName) • \($0.displayPrice)" })
                } catch {
                    print("🧪 SK2 fetch error:", error.localizedDescription)
                }
            }
#endif
        }
        .onChange(of: appVM.subscriptionState) { _ in
            clampReminderSelectionIfNeeded()
            logSubscriptionUIResolution()
        }
        .onDisappear {
            saveTask?.cancel()
        }
        // Hide the nav bar so the custom layout can use the full vertical space.
        .toolbar(.hidden, for: .navigationBar)
        .brainMailDynamicTypeRange()
    }

    private var statsColumns: [GridItem] {
        let columnCount = usesAccessibilityLayout ? 1 : 3
        return Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
            count: columnCount
        )
    }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.brainMailUsesAccessibilityLayout
    }

    // MARK: - Settings list

    private var settingsList: some View {
        VStack(spacing: usesAccessibilityLayout ? 16 : 12) {
            remindersPerWeekInlineCard
            myExperienceSection
            accountSection
        }
    }

    private var remindersPerWeekInlineCard: some View {
        VStack(alignment: .center, spacing: usesAccessibilityLayout ? 14 : 9) {
            remindersPerWeekHeaderTitle
            .frame(maxWidth: .infinity, alignment: .center)

            RemindersPerWeekSliderSection(
                remindersPerWeek: $remindersPerWeek,
                showsCenteredValue: false,
                onChange: persistSettingsDebounced,
                onWhy: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showFreeLimitsWhy = true
                    }
                },
                onUpgrade: {
                    RevenueCatManager.shared.forceIdentify(reason: "statsReminderUpgrade") {
                        DispatchQueue.main.async {
                            activeSheet = .paywall
                        }
                    }
                }
            )
            .environmentObject(appVM)
        }
        .padding(.horizontal, usesAccessibilityLayout ? 16 : 16)
        .padding(.vertical, usesAccessibilityLayout ? 15 : 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        )
    }

    private var remindersPerWeekHeaderTitle: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.figmaBlue)
                .frame(width: 24, height: 24)
                .background(Color.figmaBlue.opacity(0.08), in: Circle())
                .dynamicTypeSize(.xSmall ... (usesAccessibilityLayout ? .accessibility1 : .large))
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Reminders per Week: ")
                    .foregroundColor(.black)
                    .statsSettingsText(.settingsRowTitle)
                Text(SettingsHelpers.remindersDisplay(effectiveRemindersPerWeek))
                    .foregroundColor(.figmaBlue)
                    .statsSettingsText(.settingsRowTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .multilineTextAlignment(.center)
            .lineLimit(usesAccessibilityLayout ? 2 : 1)
            .minimumScaleFactor(usesAccessibilityLayout ? 0.92 : 0.86)
            .accessibilityLabel("Reminders per Week: \(SettingsHelpers.remindersDisplay(effectiveRemindersPerWeek))")
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var effectiveRemindersPerWeek: Double {
        let minReminders: Double = 1
        let maxReminders = appVM.maxRemindersPerWeekForCurrentSubscription
        return min(max(remindersPerWeek, minReminders), maxReminders)
    }

    private func logSubscriptionUIResolution() {
#if DEBUG
        print(
            "🔐 [Subscription][StatsUI] state=\(appVM.subscriptionState.rawValue) upgradeBanner=\(appVM.shouldShowUpgradeMessaging) sliderMax=\(appVM.maxRemindersPerWeekForCurrentSubscription) reason=\(appVM.subscriptionResolutionReason)"
        )
#endif
    }

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title)
            .statsSettingsText(.sectionHeader)
            .foregroundColor(.figmaBlue)
            .padding(.horizontal, 18)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, usesAccessibilityLayout ? 8 : 4)
    }

    private var myExperienceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsSectionHeader("My Experience")

            VStack(spacing: 0) {
                SettingsRow(
                    title: "Message Window",
                    value: "\(SettingsHelpers.hourLabel(quietStartHour)) - \(SettingsHelpers.hourLabel(quietEndHour))",
                    isDestructive: false,
                    action: { activeSheet = .sendWindow }
                )

                SettingsRow(
                    title: "Time Zone",
                    value: SettingsHelpers.timeZoneCityDisplayName(tzIdentifier),
                    isDestructive: false,
                    action: { activeSheet = .timeZone }
                )

                SettingsRow(
                    title: "Subscription",
                    value: nil,
                    isDestructive: false,
                    action: { activeSheet = .subscription }
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
                    action: { activeSheet = .communityGuidelines }
                )

                SettingsRow(
                    title: "Log Out",
                    value: nil,
                    isDestructive: true,
                    showsChevron: false,
                    action: {
                        saveTask?.cancel()
                        appVM.logout()
                    }
                )

                Color.clear.frame(height: 6)

                SettingsRow(
                    title: "Delete Account",
                    value: nil,
                    isDestructive: true,
                    showsChevron: false,
                    action: { activeSheet = .deleteAccount }
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

        let addr = "brainmailhelp@gmail.com"
        let subject = "BrainMail Support"
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
        settingsSaveSequence += 1
        let sequence = settingsSaveSequence
        let settings = UserSettingsSync.currentFromAppStorage()
        let expectedUid = appVM.user?.uid
        let revision = Int64(Date().timeIntervalSince1970 * 1000)

        saveTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 600_000_000) // 0.6s debounce
                try Task.checkCancellation()
                guard sequence == settingsSaveSequence else { return }
                guard expectedUid == appVM.user?.uid else { return }

                print("🧪 committing settings batch")
                try await UserSettingsSync.pushAndApply(
                    settings: settings,
                    expectedUid: expectedUid,
                    clientRevision: revision
                )
                print("✅ pushAndApply (right panel) OK")
            } catch is CancellationError {
                print("⚠️ pushAndApply (right panel) cancelled")
            } catch {
                print("❌ pushAndApply (right panel) failed:", error.localizedDescription)
            }
        }
    }

    private func clampReminderSelectionIfNeeded() {
        guard appVM.subscriptionState.isResolved else { return }
        let maxReminders = appVM.maxRemindersPerWeekForCurrentSubscription
        let clamped = min(max(remindersPerWeek, SubscriptionLimits.minRemindersPerWeek), maxReminders)
        guard clamped != remindersPerWeek else { return }
        remindersPerWeek = clamped
        persistSettingsDebounced()
    }

}

// MARK: - Active sheet enum

enum ActiveSettingsSheet: Hashable, Identifiable {
    case sendWindow
    case timeZone
    case subscription
    case contactUs
    case deleteAccount
    case paywall
    case communityGuidelines

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
        Group {
            if usesAccessibilityLayout {
                VStack(alignment: .center, spacing: 12) {
                    statIcon(systemImage)
                    statLabel(title, alignment: .center)
                    statMetric(value: value, suffix: suffix, alignment: .center)
                }
            } else {
                VStack(alignment: .center, spacing: 10) {
                    statIcon(systemImage)
                    statLabel(title, alignment: .center)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
                    statMetric(value: value, suffix: suffix, alignment: .center)
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .center)
                }
            }
        }
        .padding(usesAccessibilityLayout ? 14 : 12)
        .frame(maxWidth: .infinity, minHeight: usesAccessibilityLayout ? 118 : 146)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func statIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.bold))
            .foregroundColor(.figmaBlue)
            .frame(width: usesAccessibilityLayout ? 34 : nil, height: usesAccessibilityLayout ? 34 : 26)
            .dynamicTypeSize(.xSmall ... (usesAccessibilityLayout ? .accessibility1 : .large))
    }

    private func statLabel(_ title: String, alignment: TextAlignment) -> some View {
        Text(title)
            .statsSettingsText(.statCardLabel)
            .foregroundColor(.black)
            .multilineTextAlignment(alignment)
            .lineLimit(usesAccessibilityLayout && title.contains(" ") ? 2 : 1)
            .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
    }

    private func statMetric(value: String, suffix: String?, alignment: TextAlignment) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .statsSettingsText(.statCardValue)
                    .foregroundColor(.figmaBlue)
                    .monospacedDigit()

                if let suffix = suffix {
                    Text(suffix)
                        .statsSettingsText(.statCardUnit)
                        .foregroundColor(.black)
                }
            }

            VStack(alignment: stackAlignment(for: alignment), spacing: 2) {
                Text(value)
                    .statsSettingsText(.statCardValue)
                    .foregroundColor(.figmaBlue)
                    .monospacedDigit()

                if let suffix = suffix {
                    Text(suffix)
                        .statsSettingsText(.statCardUnit)
                        .foregroundColor(.black)
                }
            }
        }
        .multilineTextAlignment(alignment)
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
    }

    private func frameAlignment(for textAlignment: TextAlignment) -> Alignment {
        switch textAlignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center:
            return .center
        }
    }

    private func stackAlignment(for textAlignment: TextAlignment) -> HorizontalAlignment {
        switch textAlignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center:
            return .center
        }
    }
}

// MARK: - SettingsRow

struct SettingsRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let value: String?
    let isDestructive: Bool
    var showsChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            rowContent
            .padding(.vertical, usesAccessibilityLayout ? 16 : 14)
            .padding(.horizontal, usesAccessibilityLayout ? 18 : 20)
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

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.brainMailUsesAccessibilityLayout
    }

    @ViewBuilder
    private var rowContent: some View {
        if usesAccessibilityLayout {
            verticalContent
        } else {
            horizontalContent
        }
    }

    private var horizontalContent: some View {
        HStack(alignment: .center, spacing: 12) {
            titleText
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)

            trailingContent
                .layoutPriority(0)
        }
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                titleText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(2)

                if showsChevron {
                    chevronIcon
                }
            }

            if let value {
                valueText(value)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .statsSettingsText(.settingsRowTitle)
            .foregroundColor(isDestructive ? .red : .black)
            .multilineTextAlignment(.leading)
    }

    private var trailingContent: some View {
        HStack(spacing: 8) {
            if let value = value {
                valueText(value)
                    .frame(maxWidth: 138, alignment: .trailing)
            }

            if showsChevron {
                chevronIcon
            }
        }
        .frame(minWidth: showsChevron ? 14 : 0, alignment: .trailing)
    }

    private func valueText(_ value: String) -> some View {
        Text(value)
            .statsSettingsText(.settingsRowValue)
            .foregroundColor(isDestructive ? .red : .figmaBlue)
            .multilineTextAlignment(usesAccessibilityLayout ? .leading : .trailing)
    }

    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .foregroundColor(Color(white: 0.45))
            .font(.footnote.weight(.semibold))
            .frame(width: 14)
            .dynamicTypeSize(.xSmall ... .large)
    }
}


struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Settings sub-pages

private struct SettingsSubpageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color(red: 244/255, green: 248/255, blue: 255/255),
                Color.figmaBlue.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct SettingsSubpageHandle: View {
    var body: some View {
        Capsule()
            .fill(Color.black.opacity(0.14))
            .frame(width: 42, height: 5)
            .padding(.top, 10)
            .accessibilityHidden(true)
    }
}

private struct SettingsSubpageDismissChevron: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.36))
                .frame(width: 44, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
        .padding(.top, 8)
    }
}

private struct SettingsSubpageHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let systemImage: String
    let title: String
    let subtitle: String
    let animate: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.figmaBlue.opacity(0.16),
                                Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.14),
                                Color.white.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 6,
                            endRadius: 58
                        )
                    )
                    .frame(width: 116, height: 116)
                    .scaleEffect(animate ? 1.04 : 0.96)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: animate)

                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.figmaBlue)
                    .padding(22)
                    .background(Color.white.opacity(0.86), in: Circle())
                    .shadow(color: Color.figmaBlue.opacity(0.12), radius: 16, x: 0, y: 8)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Color.black.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .lineLimit(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 2 : 1)
                    .minimumScaleFactor(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 0.92 : 0.86)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(Color.black.opacity(0.56))
                    .multilineTextAlignment(.center)
                    .lineLimit(dynamicTypeSize.brainMailUsesAccessibilityLayout ? nil : 3)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 390)
        }
    }
}

private struct SettingsSubpageCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(18)
        .frame(maxWidth: 430, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: Color.black.opacity(0.055), radius: 18, x: 0, y: 9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
    }
}

private struct SettingsSubpageDoneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .foregroundColor(.white)
            .background(Color.figmaBlue)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: Color.figmaBlue.opacity(0.20), radius: 14, x: 0, y: 7)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct RemindersPerWeekSheet: View {
    @EnvironmentObject private var appVM: AppViewModel
    @Binding var remindersPerWeek: Double
    @State private var animateHeader = false

    var onChange: () -> Void
    var onDone: () -> Void

    var body: some View {
        ZStack {
            SettingsSubpageBackground()

            GeometryReader { proxy in
                let isCompact = proxy.size.height < 650

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isCompact ? 18 : 24) {
                        SettingsSubpageHandle()

                        SettingsSubpageHeader(
                            systemImage: "bell.badge.fill",
                            title: "Reminders per Week",
                            subtitle: appVM.shouldShowUpgradeMessaging
                                ? "Free plans can receive up to 3 random reminders each week."
                                : appVM.subscriptionState == .loading
                                ? "Checking your subscription access."
                                : "Choose how many automatic reminders feel supportive.",
                            animate: animateHeader
                        )

                        SettingsSubpageCard {
                            RemindersPerWeekSliderSection(
                                remindersPerWeek: $remindersPerWeek,
                                showsCenteredValue: true,
                                onChange: onChange,
                                onWhy: nil,
                                onUpgrade: nil
                            )
                            .environmentObject(appVM)
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: isCompact ? 8 : 16)

                        Button("Done") { onDone() }
                            .buttonStyle(SettingsSubpageDoneButtonStyle())
                            .padding(.horizontal, 24)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom + 16, 24))
                    }
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .onAppear { animateHeader = true }
        .onDisappear { animateHeader = false }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .brainMailDynamicTypeRange()
    }
}

private struct RemindersPerWeekSliderSection: View {
    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var remindersPerWeek: Double

    let showsCenteredValue: Bool
    var onChange: () -> Void
    var onWhy: (() -> Void)?
    var onUpgrade: (() -> Void)?

    private let minReminders: Double = SubscriptionLimits.minRemindersPerWeek
    private let freeMaxReminders: Double = SubscriptionLimits.freeMaxRemindersPerWeek
    private let maxReminders: Double = SubscriptionLimits.proMaxRemindersPerWeek
    private let stepReminders: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: usesAccessibilityLayout ? 14 : 8) {
            if showsCenteredValue {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(SettingsHelpers.remindersDisplay(displayedReminders))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(.figmaBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(usesAccessibilityLayout ? 0.92 : 0.82)
                        .dynamicTypeSize(.xSmall ... (usesAccessibilityLayout ? .accessibility3 : .xLarge))

                    Text("per week")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color.black.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .dynamicTypeSize(.xSmall ... (usesAccessibilityLayout ? .accessibility3 : .large))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityElement(children: .combine)
            }

            if appVM.subscriptionState == .loading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.figmaBlue)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.gray.opacity(0.16))
                        .frame(height: 8)
                }
                .frame(height: 44)
            } else {
                Slider(
                    value: remindersBinding,
                    in: minReminders...availableMaxReminders,
                    step: stepReminders
                )
                .tint(.figmaBlue)
                .onChange(of: remindersPerWeek) { _ in onChange() }
            }

            HStack {
                Text("\(SettingsHelpers.remindersDisplay(minReminders))")
                Spacer()
                Text("\(SettingsHelpers.remindersDisplay(availableMaxReminders))")
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(Color.black.opacity(0.42))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .dynamicTypeSize(.xSmall ... (usesAccessibilityLayout ? .accessibility3 : .large))

            if appVM.shouldShowUpgradeMessaging {
                upgradeLimitBanner
            }
        }
    }

    private var upgradeLimitBanner: some View {
        Group {
            if usesAccessibilityLayout {
                VStack(alignment: .leading, spacing: 9) {
                    upgradeLimitMessage
                    upgradeLimitButtons
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 8) {
                        upgradeLimitMessage
                            .layoutPriority(1)
                        upgradeLimitButtons
                    }

                    VStack(alignment: .trailing, spacing: 7) {
                        upgradeLimitMessage
                        upgradeLimitButtons
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .foregroundColor(Color.black.opacity(0.62))
        .padding(.horizontal, usesAccessibilityLayout ? 12 : 10)
        .padding(.vertical, usesAccessibilityLayout ? 10 : 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.figmaBlue.opacity(0.07))
        )
        .dynamicTypeSize(.xSmall ... (usesAccessibilityLayout ? .accessibility4 : .large))
    }

    private var upgradeLimitMessage: some View {
        HStack(alignment: usesAccessibilityLayout ? .top : .center, spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.figmaBlue)
                .padding(.top, usesAccessibilityLayout ? 2 : 0)
                .accessibilityHidden(true)

            Text("Upgrade to unlock up to 14 reminders per week.")
                .font(.footnote.weight(.medium))
                .lineLimit(usesAccessibilityLayout ? nil : 2)
                .minimumScaleFactor(usesAccessibilityLayout ? 0.92 : 0.9)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var upgradeLimitButtons: some View {
        if let onWhy, let onUpgrade {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    upgradeLimitWhyButton(action: onWhy)
                    upgradeLimitUpgradeButton(action: onUpgrade)
                }

                VStack(alignment: .trailing, spacing: 7) {
                    upgradeLimitWhyButton(action: onWhy)
                    upgradeLimitUpgradeButton(action: onUpgrade)
                }
            }
            .frame(minHeight: usesAccessibilityLayout ? 44 : 34, alignment: .center)
            .fixedSize(horizontal: !usesAccessibilityLayout, vertical: false)
        }
    }

    private func upgradeLimitWhyButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Why?")
                .statsSettingsText(.freeBannerButton)
        }
        .frame(minHeight: usesAccessibilityLayout ? 38 : 28, alignment: .center)
        .padding(.horizontal, usesAccessibilityLayout ? 13 : 9)
        .padding(.vertical, usesAccessibilityLayout ? 5 : 3)
        .background(Color.white.opacity(0.72))
        .foregroundColor(.black.opacity(0.8))
        .clipShape(Capsule())
        .contentShape(Rectangle())
    }

    private func upgradeLimitUpgradeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Upgrade")
                .statsSettingsText(.freeBannerButton)
        }
        .frame(minHeight: usesAccessibilityLayout ? 38 : 28, alignment: .center)
        .padding(.horizontal, usesAccessibilityLayout ? 14 : 10)
        .padding(.vertical, usesAccessibilityLayout ? 5 : 3)
        .background(Color.figmaBlue)
        .foregroundColor(.white)
        .clipShape(Capsule())
        .contentShape(Rectangle())
    }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.brainMailUsesAccessibilityLayout
    }

    private var displayedReminders: Double {
        min(max(remindersPerWeek, minReminders), availableMaxReminders)
    }

    private var availableMaxReminders: Double {
        min(maxReminders, max(freeMaxReminders, appVM.maxRemindersPerWeekForCurrentSubscription))
    }

    private var remindersBinding: Binding<Double> {
        if appVM.shouldUseProReminderRange {
            return Binding(
                get: { min(max(remindersPerWeek, minReminders), availableMaxReminders) },
                set: { remindersPerWeek = min(max($0, minReminders), availableMaxReminders) }
            )
        }

        return Binding(
            get: { min(max(remindersPerWeek, minReminders), freeMaxReminders) },
            set: { remindersPerWeek = min(max($0, minReminders), freeMaxReminders) }
        )
    }
}

private struct FreeLimitsWhyOverlay: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.20)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack {
                        Spacer(minLength: max(proxy.safeAreaInsets.top + 24, 28))

                        VStack(spacing: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 18 : 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.figmaBlue.opacity(0.11))
                                    .frame(width: 54, height: 54)

                                Image(systemName: "message.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.figmaBlue)
                            }
                            .accessibilityHidden(true)

                            VStack(spacing: 9) {
                                Text("Why the limits?")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.80))
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("I’m sorry it can’t be unlimited! Unfortunately, it costs money on the backend to send toll-free SMS, so I had to put up loss guardrails for free users.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.black.opacity(0.60))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Button(action: onDismiss) {
                                Text("OK")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 54 : 50)
                                    .background(Color.figmaBlue)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 22 : 20)
                        .frame(maxWidth: 350)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.white.opacity(0.97))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.90), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 14)
                        .padding(.horizontal, 24)

                        Spacer(minLength: max(proxy.safeAreaInsets.bottom + 24, 28))
                    }
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .brainMailDynamicTypeRange()
    }
}

struct SendWindowSheet: View {
    @Binding var startHour: Double
    @Binding var endHour: Double
    @State private var animateHeader = false

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
        ZStack {
            SettingsSubpageBackground()

            GeometryReader { proxy in
                let isCompact = proxy.size.height < 650

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isCompact ? 18 : 24) {
                        SettingsSubpageDismissChevron { onDone() }

                        SettingsSubpageHeader(
                            systemImage: "moon.zzz.fill",
                            title: "Message Window",
                            subtitle: "Choose the hours a reminder text would be welcome.",
                            animate: animateHeader
                        )
                        .padding(.horizontal, 24)

                        SettingsSubpageCard {
                            VStack(spacing: 6) {
                                Text("\(SettingsHelpers.hourLabel(startHour)) - \(SettingsHelpers.hourLabel(endHour))")
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(.figmaBlue)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                    .frame(maxWidth: .infinity, alignment: .center)

                                Text("Local delivery window")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(Color.black.opacity(0.48))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                            }
                            .padding(.vertical, 4)

                            RangeSlider(
                                value: binding,
                                in: 0.0...24.0,
                                step: 1.0
                            )
                            .onChange(of: startHour) { _ in onChange() }
                            .onChange(of: endHour) { _ in onChange() }

                            HStack {
                                Text("12 AM")
                                Spacer()
                                Text("12 PM")
                                Spacer()
                                Text("12 AM")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.black.opacity(0.42))

                            Text("Reminders are only sent inside this window.")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(Color.black.opacity(0.58))
                                .lineLimit(2)
                                .minimumScaleFactor(0.9)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.figmaBlue.opacity(0.07))
                                )
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: isCompact ? 8 : 16)

                        Button("Done") { onDone() }
                            .buttonStyle(SettingsSubpageDoneButtonStyle())
                            .padding(.horizontal, 24)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom + 16, 24))
                    }
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .onAppear { animateHeader = true }
        .onDisappear { animateHeader = false }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .brainMailDynamicTypeRange()
    }
}

struct TimeZoneSheet: View {
    @Binding var tzIdentifier: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var animateHeader = false

    var onChange: () -> Void
    var onDone: () -> Void

    private let usTimeZones = SettingsHelpers.usTimeZones()

    var body: some View {
        ZStack {
            SettingsSubpageBackground()

            GeometryReader { proxy in
                let isCompact = proxy.size.height < 650
                let listMaxHeight = max(proxy.size.height * (isCompact ? 0.34 : 0.42), 220)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isCompact ? 18 : 24) {
                        SettingsSubpageDismissChevron { onDone() }

                        SettingsSubpageHeader(
                            systemImage: "globe.americas.fill",
                            title: "Time Zone",
                            subtitle: "Choose the location used for reminder timing.",
                            animate: animateHeader
                        )
                        .padding(.horizontal, 24)

                        SettingsSubpageCard {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 0) {
                                    ForEach(usTimeZones, id: \.self) { id in
                                        Button {
                                            tzIdentifier = id
                                            onChange()
                                        } label: {
                                            HStack(spacing: 12) {
                                                Text(SettingsHelpers.timeZoneCityDisplayNameWithGMT(id))
                                                    .font(.body)
                                                    .foregroundColor(.figmaBlue)
                                                    .lineLimit(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 2 : 1)
                                                    .minimumScaleFactor(0.86)
                                                    .fixedSize(horizontal: false, vertical: true)

                                                Spacer(minLength: 8)

                                                if id == tzIdentifier {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.body.weight(.semibold))
                                                        .foregroundColor(.figmaBlue)
                                                }
                                            }
                                            .padding(.vertical, 11)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)

                                        if id != usTimeZones.last {
                                            Divider()
                                                .overlay(Color.black.opacity(0.05))
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: listMaxHeight)
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: isCompact ? 8 : 16)

                        Button("Done") { onDone() }
                            .buttonStyle(SettingsSubpageDoneButtonStyle())
                            .padding(.horizontal, 24)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom + 16, 24))
                    }
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .onAppear { animateHeader = true }
        .onDisappear { animateHeader = false }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .brainMailDynamicTypeRange()
        .tint(.figmaBlue)
    }
}

struct SubscriptionOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var appVM: AppViewModel
    @ObservedObject var revenueCat: RevenueCatManager = .shared

    var onStartSubscription: () -> Void
    @Binding var restoreMessage: String?
    @State private var animateHeader = false

    init(appVM: AppViewModel, onStartSubscription: @escaping () -> Void, restoreMessage: Binding<String?>) {
        self.appVM = appVM
        self.onStartSubscription = onStartSubscription
        self._restoreMessage = restoreMessage
    }

    var body: some View {
        ZStack {
            SettingsSubpageBackground()

            GeometryReader { proxy in
                let isCompact = proxy.size.height < 650

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isCompact ? 18 : 24) {
                        SettingsSubpageDismissChevron { dismiss() }

                        SettingsSubpageHeader(
                            systemImage: appVM.isProUser ? "checkmark.seal.fill" : "sparkles",
                            title: "Subscription",
                            subtitle: appVM.isProUser
                                ? "Your BrainMail Pro access is active."
                                : appVM.subscriptionState == .loading
                                ? "Checking your subscription access."
                                : "Unlock roomier reminder limits and unlimited instant sends.",
                            animate: animateHeader
                        )
                        .padding(.horizontal, 24)

                        SettingsSubpageCard {
                            subscriptionStatusCard

                            SubscriptionSection(
                                appVM: appVM,
                                revenueCat: revenueCat,
                                onStartSubscription: onStartSubscription,
                                restoreMessage: $restoreMessage
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: isCompact ? 8 : 16)

                        Button("Done") { dismiss() }
                            .buttonStyle(SettingsSubpageDoneButtonStyle())
                            .padding(.horizontal, 24)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom + 16, 24))
                    }
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .multilineTextAlignment(.center)
        .onAppear { animateHeader = true }
        .onDisappear { animateHeader = false }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .brainMailDynamicTypeRange()
    }

    private var subscriptionStatusCard: some View {
        Group {
            if appVM.subscriptionState == .free {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current plan: Free")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.black.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.56))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.045), lineWidth: 1)
                )
            } else {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.figmaBlue.opacity(0.10))
                            .frame(width: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 48 : 42,
                                   height: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 48 : 42)

                        Image(systemName: appVM.isProUser ? "checkmark.circle.fill" : "clock.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.figmaBlue)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(subscriptionStatusTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(Color.black.opacity(0.80))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subscriptionStatusSubtitle)
                            .font(.footnote)
                            .foregroundColor(Color.black.opacity(0.56))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.figmaBlue.opacity(0.07))
                )
            }
        }
    }

    private var subscriptionStatusTitle: String {
        switch appVM.subscriptionState {
        case .subscribed:
            return "Subscribed"
        case .loading:
            return appVM.lastKnownSubscriptionWasPro ? "Subscribed" : "Checking status"
        case .expired:
            return "Subscription expired"
        case .error:
            return appVM.lastKnownSubscriptionWasPro ? "Subscribed" : "Status unavailable"
        case .free:
            return "Free plan"
        }
    }

    private var subscriptionStatusSubtitle: String {
        switch appVM.subscriptionState {
        case .subscribed:
            return "Thanks for using BrainMail."
        case .loading:
            return appVM.lastKnownSubscriptionWasPro
                ? "Keeping your Pro access while we refresh."
                : "We’re refreshing RevenueCat."
        case .expired:
            return "Upgrade whenever you want more room."
        case .error:
            return appVM.lastKnownSubscriptionWasPro
                ? "Keeping your last known Pro access for now."
                : "We couldn’t refresh purchases just now."
        case .free:
            return "Upgrade whenever you want more room."
        }
    }
}

struct ContactUsMailSheet: View {
    var body: some View {
        MailView(
            recipients: ["brainmailhelp@gmail.com"],
            subject: "BrainMail Support"
        )
    }
}
