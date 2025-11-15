// ========================================================
// File: Views/Settings/Sections/SubscriptionSection.swift
// ========================================================
import SwiftUI

struct SubscriptionSection: View {
    let appVM: AppViewModel
    @ObservedObject var revenueCat: RevenueCatManager

    @Binding var showPaywall: Bool
    @Binding var restoreMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let isSubscribed = revenueCat.entitlementActive
            let willRenew = revenueCat.entitlementWillRenew
            let expiration = revenueCat.entitlementExpirationDate

            let now = Date()
            let trialEnd = appVM.user?.trialEndsAt
            let onTrial = (trialEnd ?? .distantPast) > now && !isSubscribed

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
    }
}
