// ============================
// File: Views/Sheets/SendNowSheet.swift
// ============================
import SwiftUI
import UIKit

@MainActor
struct SendNowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel

    @State private var isSending = false
    @State private var errorMessage: String? = nil
    @State private var showWeeklyLimitAlert = false
    @State private var animateIllustration = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 244/255, green: 248/255, blue: 255/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let isCompact = proxy.size.height < 650

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isCompact ? 18 : 24) {
                        Spacer(minLength: isCompact ? 30 : 44)

                        SendNowIllustration(isSending: isSending, animate: animateIllustration)
                            .frame(height: isCompact ? 180 : 232)
                            .accessibilityHidden(true)

                        VStack(spacing: 10) {
                            Text("Need some of your own wisdom right now?")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(Color.black.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("We’ll send a random entry from your saved bank.")
                                .font(.subheadline)
                                .foregroundColor(Color.black.opacity(0.58))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .frame(maxWidth: 420)

                        Spacer(minLength: 12)

                        VStack(spacing: 12) {
                            Button {
                                Task { await sendNow() }
                            } label: {
                                Group {
                                    if isSending {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text("Text me")
                                            .font(.headline)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.82)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 52)
                            }
                            .foregroundColor(.white)
                            .background((isSending || appVM.hasUsedFreeInstantSendThisWeek) ? Color.figmaBlue.opacity(0.6) : Color.figmaBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.figmaBlue.opacity(isSending ? 0 : 0.22), radius: 16, x: 0, y: 8)
                            .disabled(isSending)

                            Button(action: { dismiss() }) {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 52)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            }
                            .foregroundColor(Color.black.opacity(0.62))
                            .background(Color.white.opacity(0.78))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom + 16, 24))
                    }
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height)
                }
            }

            VStack {
                SendNowDismissChevron { dismiss() }
                Spacer()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
        .onAppear {
            appVM.refreshRevenueCatEntitlement(reason: "sendNowSheetAppear")
            restartIllustration()
        }
        .onDisappear { animateIllustration = false }
        .brainMailDynamicTypeRange()
        .alert("Weekly Instant Send Used", isPresented: $showWeeklyLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You already used your weekly instant send, upgrade for unlimited!")
        }
    }

    private func sendNow() async {
        guard !isSending else { return }
        if appVM.hasUsedFreeInstantSendThisWeek {
            appVM.debugLogUsageGate("sendNowSheet.clientBlockedWeeklyInstant")
            showWeeklyLimitAlert = true
            return
        }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            try await appVM.sendOneNow()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restartIllustration() {
        animateIllustration = false
        DispatchQueue.main.async {
            animateIllustration = true
        }
    }
}

private struct SendNowDismissChevron: View {
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

private struct SendNowIllustration: View {
    let isSending: Bool
    let animate: Bool
    @State private var cycleStart = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !animate)) { timeline in
            let elapsed = animate ? timeline.date.timeIntervalSince(cycleStart) : 0
            let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: 3.8) / 3.8)

            LockScreenNotificationAnimation(
                phase: phase,
                isSending: isSending
            )
        }
        .onAppear {
            cycleStart = Date()
        }
        .onChange(of: animate) { isAnimating in
            if isAnimating {
                cycleStart = Date()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LockScreenNotificationAnimation: View {
    let phase: CGFloat
    let isSending: Bool

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let availableHeight = max(proxy.size.height, 1)
            let phoneHeight = min(availableHeight * 0.92, 214)
            let phoneWidth = min(max(phoneHeight * 0.56, 106), min(availableWidth * 0.54, 132))
            let bannerWidth = phoneWidth * 0.86
            let bannerHeight = min(max(phoneHeight * 0.21, 42), 50)
            let slideProgress = slideProgress(for: phase)
            let bannerY = (-phoneHeight * 0.50) + (phoneHeight * 0.27 * slideProgress) + bounceOffset(for: phase)
            let landingEnergy = landingEnergy(for: phase)
            let bannerOpacity = notificationOpacity(for: phase)
            let wobble = sin(Double(phase) * 118) * Double(landingEnergy) * 1.8

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.96),
                                Color.figmaBlue.opacity(0.11),
                                Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.17)
                            ],
                            center: .center,
                            startRadius: 18,
                            endRadius: 132
                        )
                    )
                    .frame(width: min(availableWidth * 0.84, 238), height: min(availableWidth * 0.84, 238))
                    .scaleEffect(1 + landingEnergy * 0.018 + (isSending ? 0.01 : 0))

                LockScreenPhone(width: phoneWidth, height: phoneHeight)
                    .scaleEffect(1 + landingEnergy * 0.006)

                LockScreenNotificationBanner(width: bannerWidth, height: bannerHeight, pulse: landingEnergy)
                    .opacity(bannerOpacity)
                    .scaleEffect(0.98 + slideProgress * 0.02 + landingEnergy * 0.018)
                    .offset(x: CGFloat(wobble), y: bannerY)
            }
            .frame(width: availableWidth, height: availableHeight)
        }
    }

    private func slideProgress(for phase: CGFloat) -> CGFloat {
        if phase < 0.08 { return 0 }
        if phase < 0.36 { return easeOutCubic((phase - 0.08) / 0.28) }
        if phase < 0.78 { return 1 }
        return 0
    }

    private func notificationOpacity(for phase: CGFloat) -> Double {
        if phase < 0.05 { return 0 }
        if phase < 0.13 { return Double(easeOutCubic((phase - 0.05) / 0.08)) }
        if phase < 0.76 { return 1 }
        if phase < 0.86 { return Double(1 - easeInOut((phase - 0.76) / 0.10)) }
        return 0
    }

    private func landingEnergy(for phase: CGFloat) -> CGFloat {
        guard phase >= 0.34 && phase <= 0.56 else { return 0 }
        let local = (phase - 0.34) / 0.22
        return max(0, 1 - local)
    }

    private func bounceOffset(for phase: CGFloat) -> CGFloat {
        guard phase >= 0.34 && phase <= 0.52 else { return 0 }
        let local = (phase - 0.34) / 0.18
        return sin(local * .pi * 2.2) * (1 - local) * 7
    }

    private func easeOutCubic(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return 1 - CGFloat(pow(Double(1 - clamped), 3))
    }

    private func easeInOut(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}

private struct LockScreenPhone: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.82),
                        Color(red: 246/255, green: 249/255, blue: 255/255).opacity(0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.24, style: .continuous)
                    .stroke(Color.figmaBlue.opacity(0.46), lineWidth: 3)
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.figmaBlue.opacity(0.20))
                    .frame(width: width * 0.24, height: 4)
                    .padding(.top, height * 0.07)
            }
            .shadow(color: Color.figmaBlue.opacity(0.14), radius: 20, x: 0, y: 10)
    }
}

private struct LockScreenNotificationBanner: View {
    let width: CGFloat
    let height: CGFloat
    let pulse: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.figmaBlue.opacity(0.34 + pulse * 0.16))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(Color.figmaBlue.opacity(0.28))
                    .frame(width: width * 0.42, height: 6)

                Capsule()
                    .fill(Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.34))
                    .frame(width: width * 0.58, height: 5)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: min(18, height * 0.38), style: .continuous)
                .fill(Color.white.opacity(0.94))
                .shadow(color: Color.black.opacity(0.09), radius: 14, x: 0, y: 7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: min(18, height * 0.38), style: .continuous)
                .stroke(Color.white.opacity(0.84), lineWidth: 1)
        )
    }
}
