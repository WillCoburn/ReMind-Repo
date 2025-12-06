// ============================
// File: Views/RightPanel/RightPanelPlaceholderView.swift
// ============================
import MessageUI
import PhotosUI
import StoreKit
import SwiftUI

struct RightPanelPlaceholderView: View {
    @EnvironmentObject private var appVM: AppViewModel

    @AppStorage("remindersPerWeek") private var remindersPerWeek: Double = 7.0 // 1...20
    @AppStorage("tzIdentifier")    private var tzIdentifier: String = TimeZone.current.identifier
    @AppStorage("quietStartHour")  private var quietStartHour: Double = 9     // 0...24
    @AppStorage("quietEndHour")    private var quietEndHour: Double = 22      // 0...24
    @AppStorage("bgImageBase64")   private var bgImageBase64: String = ""

    @State private var photoItem: PhotosPickerItem?
    @State private var loadError: String?
    @State private var pendingSaveWorkItem: DispatchWorkItem?
    @State private var activeSheet: ActiveSettingsSheet?
    @State private var showPaywall = false
    @State private var restoreMessage: String?
    @State private var mailError: String?

    var body: some View {
        ZStack {
            // 👇 Light brand-tinted background (NOT solid black)
            Color.white.ignoresSafeArea()
            Color.figmaBlue.opacity(0.08).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Top stat tiles
                    LazyVGrid(
                        columns: Array(repeating: .init(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
                        savedTile
                        streakTile
                        receivedTile
                    }
                    .padding(.top, 8)

                    settingsList
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("Stats & Settings")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(.top, -14)  // centers vertically
            }
        }
         .toolbarBackground(Color.figmaBlue.opacity(0.08), for: .navigationBar)
         .toolbarBackground(.visible, for: .navigationBar)
         // Improve contrast in all modes
         .toolbarColorScheme(.light, for: .navigationBar)
        
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
                    showPaywall: $showPaywall,
                    restoreMessage: $restoreMessage
                )
            case .contactUs:
                ContactUsMailSheet()
            }
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
            RevenueCatManager.shared.refreshEntitlementState()
            RevenueCatManager.shared.recomputeAndPersistActive()

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

    // MARK: - Settings list

    private var settingsList: some View {
        VStack(spacing: 12) {
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
                    title: "Delete Account",
                    value: nil,
                    isDestructive: true,
                    showsChevron: false,
                    action: {}
                )

                Color.clear.frame(height: 6)
                
                SettingsRow(
                    title: "Log Out",
                    value: nil,
                    isDestructive: true,
                    showsChevron: false,
                    action: { appVM.logout() }
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

    private func persistSettingsDebounced() {
        pendingSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            UserSettingsSync.pushAndApply { err in
                print("pushAndApply (right panel) ->", err?.localizedDescription ?? "OK")
            }
        }

        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
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
        .frame(maxWidth: .infinity, minHeight: 110).padding(12)
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

    @Binding var showPaywall: Bool
    @Binding var restoreMessage: String?

    init(appVM: AppViewModel, showPaywall: Binding<Bool>, restoreMessage: Binding<String?>) {
        self.appVM = appVM
        self._showPaywall = showPaywall
        self._restoreMessage = restoreMessage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscription")
                .font(.headline)

            SubscriptionSection(
                appVM: appVM,
                revenueCat: revenueCat,
                showPaywall: $showPaywall,
                restoreMessage: $restoreMessage
            )

            Spacer(minLength: 8)
        }
        .padding()
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
