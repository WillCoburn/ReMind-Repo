// ========================================================
// File: Views/Settings/Sections/SubscriptionSection.swift
// ========================================================
import SwiftUI

struct SubscriptionSection: View {
    let appVM: AppViewModel
    @ObservedObject var revenueCat: RevenueCatManager

    var onStartSubscription: () -> Void
    @Binding var restoreMessage: String?

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            let willRenew = revenueCat.entitlementWillRenew
            let expiration = revenueCat.entitlementExpirationDate

            if appVM.subscriptionState == .loading {
                ProgressView()
                    .tint(.figmaBlue)
                    .frame(minHeight: 48)
            } else if appVM.isProUser {
                if let expiration {
                    let dateString = DateFormatter.localizedString(
                        from: expiration,
                        dateStyle: .medium,
                        timeStyle: .short
                    )

                    Text(willRenew
                         ? "Subscription renews on: \(dateString)"
                         : "Subscription ends on: \(dateString)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Button("Start Subscription") {
                     RevenueCatManager.shared.forceIdentify {
                         onStartSubscription()
                     }
                }
                .buttonStyle(SubscriptionPrimaryButtonStyle())
            }

            if appVM.isProUser {
                Button("Manage Subscription") {
                     if let url = RevenueCatManager.shared.managementURL {
                         UIApplication.shared.open(url)
                     } else if let fallback = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                         UIApplication.shared.open(fallback)
                     }
                }
                .buttonStyle(SubscriptionSecondaryButtonStyle())
            }

            Button("Restore Purchases") {
                 RevenueCatManager.shared.restore { ok, err in
                     restoreMessage = err ?? (ok ? "Restored." : "Nothing to restore.")
                 }
            }
            .buttonStyle(SubscriptionSecondaryButtonStyle())

            Text("I'm truly sorry this can't be free, I hate it too – the backend and SMS service costs me about the subscription fee to run. Hope it's worth it to you :)")
                .font(.footnote)
                .foregroundStyle(Color.black.opacity(0.56))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.figmaBlue.opacity(0.06))
                )

            if let msg = restoreMessage {
                Text(msg)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SubscriptionPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .foregroundColor(.white)
            .background(Color.figmaBlue)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: Color.figmaBlue.opacity(0.20), radius: 14, x: 0, y: 7)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct SubscriptionSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .foregroundColor(Color.black.opacity(0.66))
            .background(Color.white.opacity(configuration.isPressed ? 0.62 : 0.82))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
    }
}
