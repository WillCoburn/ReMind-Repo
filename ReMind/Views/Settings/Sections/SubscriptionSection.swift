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

        // Center ALL content horizontally
        VStack(alignment: .center, spacing: 12) {


            let isEntitled = appVM.isEntitled
            let willRenew = revenueCat.entitlementWillRenew
            let expiration = revenueCat.entitlementExpirationDate


            let trialEnd = appVM.user?.trialEndsAt
            let onTrial = appVM.isTrialActive

            // ============================
            // Subscription Status / Trial
            // ============================
            if isEntitled {
                if let expiration {
                    let dateString = DateFormatter.localizedString(
                        from: expiration,
                        dateStyle: .medium,
                        timeStyle: .short
                    )

                    Text(willRenew
                         ? "Subscription renews on: \(dateString)"
                         : "Subscription ends on: \(dateString)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
            } else {
                if onTrial, let trialEnd {
                    let dateString = DateFormatter.localizedString(
                        from: trialEnd,
                        dateStyle: .medium,
                        timeStyle: .none
                    )

                    Text("Free trial ends: \(dateString)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Start Subscription Button
                Button("Start Subscription") {
                    
                     RevenueCatManager.shared.forceIdentify {
                         showPaywall = true
                     }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // ============================
            // Manage Subscription Button
            // ============================
            Button("Manage Subscription") {
                
                 if let url = RevenueCatManager.shared.managementURL {
                     UIApplication.shared.open(url)
                 } else if let fallback = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                     UIApplication.shared.open(fallback)
                 }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .center)

            // ============================
            // Restore Purchases Button
            // ============================
            Button("Restore Purchases") {
                
                 RevenueCatManager.shared.restore { ok, err in
                     restoreMessage = err ?? (ok ? "Restored." : "Nothing to restore.")
                 }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .center)

            // ============================
            // Footer Text
            // ============================
            Text("I'm truly sorry this can't be free, I hate it too – the backend and SMS service costs me about the subscription fee to run. Hope it's worth it to you :)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if let msg = restoreMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
    }
}
