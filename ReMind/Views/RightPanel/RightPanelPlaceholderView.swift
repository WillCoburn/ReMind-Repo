// ============================
// File: Views/RightPanel/RightPanelPlaceholderView.swift
// ============================
import MessageUI
import PhotosUI
import StoreKit
import SwiftUI

struct RightPanelPlaceholderView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @ObservedObject private var revenueCat = RevenueCatManager.shared

    @State private var showPaywall = false

    @AppStorage("remindersPerWeek") private var remindersPerWeek: Double = 7.0 // 1...20
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
                    LazyVGrid(
                        columns: Array(repeating: .init(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
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
    }

    // MARK: - Settings list

    private var settingsList: some View {
        VStack(spacing: 12) {
            if shouldShowTrialBanner, let trialEnd = appVM.user?.trialEndsAt {
                trialBanner(trialEnd)
            }
            
            // Top group
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

            // Middle group
            VStack(spacing: 0) {
                SettingsRow(
                    title: "Personalize Background",
                    value: nil,
                    isDestructive: false,
                    action: { activeSheet = .background }
                )

                SettingsRow(
                    title: "Contact Us",
                    value: nil,
                    isDestructive: false,
                    action: openSupport
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

            // Bottom group
            VStack(spacing: 0) {
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

    
    private func trialBanner(_ trialEnd: Date) -> some View {
        HStack(spacing: 12) {

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundColor(.red)

            Text("Free trial is active until \(trialEndDateString(trialEnd)).")
                .font(.footnote)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                RevenueCatManager.shared.forceIdentify {
                    showPaywall = true
                }
            } label: {
                Text("Subscribe")
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.figmaBlue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            .buttonStyle(.plain)   // IMPORTANT: prevents parent gestures from blocking taps
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.12))
        )
    }


    private var shouldShowTrialBanner: Bool {
        !appVM.isEntitled && appVM.isTrialActive
    }

    private func trialEndDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
            value: "\(appVM.user?.receivedCount ?? appVM.sentEntriesCount)"
        )
    }

    // Shared card style
    func statTile(systemImage: String, title: String, value: String, suffix: String? = nil) -> some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.figmaBlue)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.black)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.figmaBlue)

                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.black)
                }
            }

        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
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
            HStack {
                Text(title)
                    // 👇 force black so it’s visible on white even in Dark Mode
                    .foregroundColor(isDestructive ? .red : .black)

                Spacer()

                if let value = value {
                    Text(value)
                        .foregroundColor(isDestructive ? .red : .figmaBlue)
                        .lineLimit(1)
                }

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(white: 0.45))
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.gray.opacity(0.25)),
                alignment: .bottom
            )
        }
    }
}

// MARK: - Sheets (unchanged structurally)

struct RemindersPerWeekSheet: View {
    @Binding var remindersPerWeek: Double

    var onChange: () -> Void
    var onDone: () -> Void

    private let minReminders: Double = 1
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

            Slider(
                value: $remindersPerWeek,
                in: minReminders...maxReminders,
                step: stepReminders
            )
            .onChange(of: remindersPerWeek) { _ in onChange() }

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
