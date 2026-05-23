// ========================================================
// File: Views/Settings/Sections/SubscriptionSection.swift
// ========================================================
import SwiftUI

struct SubscriptionSection: View {
    let appVM: AppViewModel
    @ObservedObject var revenueCat: RevenueCatManager

    var onStartSubscription: () -> Void
    @Binding var restoreMessage: String?
    @State private var restoreMessageIsError = false
    @State private var restoreMessageClearTask: Task<Void, Never>?
    @State private var restoreTimeoutTask: Task<Void, Never>?
    @State private var restoreAttemptID = UUID()
    @State private var isRestoringPurchases = false

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

            Button {
                restorePurchases()
            } label: {
                restoreButtonLabel
            }
            .buttonStyle(SubscriptionSecondaryButtonStyle())
            .disabled(isRestoringPurchases)
            .accessibilityLabel(isRestoringPurchases ? "Restoring purchases" : "Restore purchases")

            if !appVM.isProUser {
                Text("I’m truly sorry this can’t be free, I hate it too — the backend SMS costs me the subscription fee. Just trying to break even here — hope it’s worth it to you!")
                    .font(.footnote)
                    .foregroundStyle(Color.black.opacity(0.50))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.figmaBlue.opacity(0.045))
                    )
            }

            if let msg = restoreMessage {
                Text(msg)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(restoreMessageIsError ? Color.red.opacity(0.82) : Color.figmaBlue.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.18), value: restoreMessage)
        .onDisappear {
            restoreMessageClearTask?.cancel()
            restoreTimeoutTask?.cancel()
            restoreMessageClearTask = nil
            restoreTimeoutTask = nil
            isRestoringPurchases = false
        }
    }

    private var restoreButtonLabel: some View {
        ZStack {
            Text("Restore Purchases")
                .opacity(isRestoringPurchases ? 0 : 1)

            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.black.opacity(0.54))
                    .scaleEffect(0.82)

                Text("Restoring...")
            }
            .opacity(isRestoringPurchases ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.16), value: isRestoringPurchases)
    }

    private func restorePurchases() {
        guard !isRestoringPurchases else { return }
        let attemptID = UUID()
        restoreAttemptID = attemptID
        restoreMessageClearTask?.cancel()
        restoreTimeoutTask?.cancel()
        withAnimation(.easeInOut(duration: 0.16)) {
            restoreMessage = nil
            restoreMessageIsError = false
            isRestoringPurchases = true
        }

        restoreTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled, restoreAttemptID == attemptID, isRestoringPurchases else { return }
            withAnimation(.easeInOut(duration: 0.16)) {
                isRestoringPurchases = false
            }
            setRestoreMessage("Restore is taking longer than expected. Please try again.", isError: true)
        }

        RevenueCatManager.shared.restore { ok, err, customerInfo in
            DispatchQueue.main.async {
                guard restoreAttemptID == attemptID else { return }
                restoreTimeoutTask?.cancel()
                restoreTimeoutTask = nil
                withAnimation(.easeInOut(duration: 0.16)) {
                    isRestoringPurchases = false
                }

                if let customerInfo {
                    appVM.applyFreshRevenueCatCustomerInfo(customerInfo, reason: "settingsRestorePurchases")
                }
                appVM.refreshRevenueCatEntitlement(reason: "settingsRestorePurchases")

                let message = err ?? (
                    ok
                    ? "Purchases restored."
                    : RevenueCatManager.shared.noActiveSubscriptionRestoreMessage
                )
                setRestoreMessage(message, isError: !ok || err != nil)
            }
        }
    }

    private func setRestoreMessage(_ message: String, isError: Bool) {
        restoreMessageClearTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) {
            restoreMessage = message
            restoreMessageIsError = isError
        }
        restoreMessageClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_800_000_000)
            guard restoreMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                restoreMessage = nil
            }
        }
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
