// =====================================
// File: Views/Settings/UserSettingsPanel.swift
// =====================================
import SwiftUI
import PhotosUI
import MessageUI
import StoreKit

struct UserSettingsPanel: View {


    // Bindings from parent
    @Binding var remindersPerWeek: Double
    @Binding var tzIdentifier: String
    @Binding var quietStartHour: Double
    @Binding var quietEndHour: Double
    @Binding var bgImageBase64: String

    var onClose: () -> Void

    var onSettingsChanged: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeaderBar(title: "Settings", onClose: onClose)
            Divider()

            ScrollView {
        UserSettingsForm(
             remindersPerWeek: $remindersPerWeek,
             tzIdentifier: $tzIdentifier,
             quietStartHour: $quietStartHour,
             quietEndHour: $quietEndHour,
             bgImageBase64: $bgImageBase64,
             onSettingsChanged: onSettingsChanged
         )
                .padding(16)
            }
            .background(Color.paletteIvory) 
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20, y: 8)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color.paletteIvory.ignoresSafeArea())
        .padding(.top, 8)
}
}

struct UserSettingsForm: View {
  @EnvironmentObject private var appVM: AppViewModel
  @ObservedObject private var revenueCat = RevenueCatManager.shared

  @Binding var remindersPerWeek: Double
  @Binding var tzIdentifier: String
  @Binding var quietStartHour: Double
  @Binding var quietEndHour: Double
  @Binding var bgImageBase64: String

  var onSettingsChanged: (() -> Void)? = nil

  // Local state
  @State private var photoItem: PhotosPickerItem?
  @State private var loadError: String?
  @State private var showMailSheet = false
  @State private var mailError: String?
  @State private var showPaywall = false
  @State private var restoreMessage: String?

  var body: some View {
      VStack(alignment: .leading, spacing: 20) {
          RemindersPerWeekSection(remindersPerWeek: $remindersPerWeek)
              .onChange(of: remindersPerWeek) { _ in handleSettingChange() }

          Divider()

          TimeZoneSection(
              tzIdentifier: $tzIdentifier,
              usTimeZones: SettingsHelpers.usTimeZones()
          )
          .onChange(of: tzIdentifier) { _ in handleSettingChange() }

          Divider()

          SendWindowSection(
              startHour: $quietStartHour,
              endHour: $quietEndHour,
              hourLabel: SettingsHelpers.hourLabel(_:)
          )
          .onChange(of: quietStartHour) { _ in handleSettingChange() }
          .onChange(of: quietEndHour) { _ in handleSettingChange() }

          Divider()

          BackgroundPickerSection(
              photoItem: $photoItem,
              bgImageBase64: $bgImageBase64,
              loadError: $loadError
          )
          .onChange(of: bgImageBase64) { _ in handleSettingChange() }

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

          Divider()

          Button(role: .destructive) {
              appVM.logout()
          } label: {
              Text("Log Out")
                  .frame(maxWidth: .infinity)
          }
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 12)

          Spacer(minLength: 8)
      }


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
    
    private var shouldShowTrialBanner: Bool {
        guard !revenueCat.entitlementActive else { return false }
        guard let trialEnd = appVM.user?.trialEndsAt else { return false }
        return Date() < trialEnd
    }

    private func trialEndDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func handleSettingChange() {
        onSettingsChanged?()
    }
}
