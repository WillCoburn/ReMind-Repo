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

    // Bindings from parent
    @Binding var remindersPerWeek: Double
    @Binding var tzIdentifier: String
    @Binding var quietStartHour: Double
    @Binding var quietEndHour: Double
    @Binding var bgImageBase64: String

    var onClose: () -> Void

    // Local state
    @State private var photoItem: PhotosPickerItem?
    @State private var loadError: String?
    @State private var showMailSheet = false
    @State private var mailError: String?
    @State private var showPaywall = false
    @State private var restoreMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeaderBar(title: "Settings", onClose: onClose)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    RemindersPerWeekSection(remindersPerWeek: $remindersPerWeek)

                    Divider()

                    TimeZoneSection(
                        tzIdentifier: $tzIdentifier,
                        usTimeZones: SettingsHelpers.usTimeZones()
                    )

                    Divider()

                    SendWindowSection(
                        startHour: $quietStartHour,
                        endHour: $quietEndHour,
                        hourLabel: SettingsHelpers.hourLabel(_:)
                    )

                    Divider()

                    BackgroundPickerSection(
                        photoItem: $photoItem,
                        bgImageBase64: $bgImageBase64,
                        loadError: $loadError
                    )

                    Divider()

                    FeedbackSupportSection(
                        showMailSheet: $showMailSheet,
                        mailError: $mailError
                    )

                    Divider()

                    SubscriptionSection(
                        appVM: appVM,
                        revenueCat: revenueCat,
                        showPaywall: $showPaywall,
                        restoreMessage: $restoreMessage
                    )
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

            // Optional SK2 sanity check
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
}
