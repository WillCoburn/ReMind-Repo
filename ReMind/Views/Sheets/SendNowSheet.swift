// ============================
// File: Views/Sheets/SendNowSheet.swift
// ============================
import SwiftUI
import UIKit

@MainActor
struct SendNowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel
    @ObservedObject private var revenueCat: RevenueCatManager = .shared

    @State private var isSending = false
    @State private var errorMessage: String? = nil
    @State private var showWeeklyLimitAlert = false
    @State private var animateIllustration = false

    var body: some View {
        let _ = revenueCat.entitlementActive
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

                VStack(spacing: isCompact ? 18 : 24) {
                    Spacer(minLength: isCompact ? 12 : 28)

                    SendNowIllustration(isSending: isSending, animate: animateIllustration)
                        .frame(height: isCompact ? 190 : 240)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(isSending ? "Sending your reminder..." : "Need some of your own wisdom right now?")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Color.black.opacity(0.78))
                            .multilineTextAlignment(.center)

                        Text("We’ll pull one saved thought from your journal and text it back like a note from past you.")
                            .font(.subheadline)
                            .foregroundColor(Color.black.opacity(0.58))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
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
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .foregroundColor(.white)
                        .background((isSending || appVM.hasUsedFreeInstantSendThisWeek) ? Color.figmaBlue.opacity(0.6) : Color.figmaBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.figmaBlue.opacity(isSending ? 0 : 0.22), radius: 16, x: 0, y: 8)
                        .disabled(isSending)

                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .font(.headline)
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
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .navigationTitle("Send One Now")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
        .onAppear { restartIllustration() }
        .alert("Weekly Instant Send Used", isPresented: $showWeeklyLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You already used your weekly instant send, upgrade for unlimited!")
        }
    }

    private func sendNow() async {
        guard !isSending else { return }
        if appVM.hasUsedFreeInstantSendThisWeek {
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

private struct SendNowIllustration: View {
    let isSending: Bool
    let animate: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.94),
                            Color.figmaBlue.opacity(0.10),
                            Color(red: 232/255, green: 202/255, blue: 222/255).opacity(0.14)
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: 132
                    )
                )
                .frame(width: 228, height: 228)
                .scaleEffect(animate ? 1.04 : 0.96)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: animate)

            WisdomDriftCard(width: 112, accent: Color(red: 130/255, green: 198/255, blue: 184/255))
                .rotationEffect(.degrees(animate ? -10 : -6))
                .offset(x: animate ? -76 : -64, y: animate ? 28 : 40)
                .opacity(0.82)
                .animation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true), value: animate)

            WisdomDriftCard(width: 96, accent: Color(red: 222/255, green: 174/255, blue: 202/255))
                .rotationEffect(.degrees(animate ? 10 : 6))
                .offset(x: animate ? 78 : 66, y: animate ? 44 : 30)
                .opacity(0.78)
                .animation(.easeInOut(duration: 2.9).repeatForever(autoreverses: true), value: animate)

            WisdomMessagePreview(isSending: isSending, animate: animate)
                .offset(x: animate ? 0 : -22, y: animate ? -12 : 4)
                .opacity(animate ? 1 : 0.72)
                .animation(.easeOut(duration: 0.72), value: animate)

            Image(systemName: isSending ? "paperplane.fill" : "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.figmaBlue)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.94))
                        .shadow(color: Color.figmaBlue.opacity(0.14), radius: 12, x: 0, y: 7)
                )
                .offset(x: animate ? 84 : 68, y: animate ? -76 : -62)
                .scaleEffect(isSending ? 0.92 : (animate ? 1.04 : 0.94))
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: animate)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WisdomMessagePreview: View {
    let isSending: Bool
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Capsule()
                .fill(Color.figmaBlue.opacity(isSending ? 0.30 : 0.24))
                .frame(width: 88, height: 7)
            Capsule()
                .fill(Color.figmaBlue.opacity(0.14))
                .frame(width: 134, height: 7)
            Capsule()
                .fill(Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.34))
                .frame(width: animate ? 70 : 48, height: 7)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: animate)
        }
        .padding(.leading, 24)
        .padding(.trailing, 20)
        .padding(.vertical, 17)
        .background(
            SheetIncomingMessageShape()
                .fill(Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 8)
        )
        .overlay {
            SheetIncomingMessageShape()
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        }
    }
}

private struct WisdomDriftCard: View {
    let width: CGFloat
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule()
                .fill(accent.opacity(0.32))
                .frame(width: width * 0.40, height: 5)
            Capsule()
                .fill(Color.figmaBlue.opacity(0.12))
                .frame(width: width * 0.64, height: 5)
            Capsule()
                .fill(Color.figmaBlue.opacity(0.09))
                .frame(width: width * 0.52, height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.66))
                .shadow(color: Color.black.opacity(0.045), radius: 10, x: 0, y: 6)
        )
    }
}

private struct SheetIncomingMessageShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tailWidth = min(max(rect.width * 0.07, 12), 16)
        let bubbleMinX = rect.minX + tailWidth
        let corner = min(24, rect.height * 0.46, (rect.width - tailWidth) / 2)
        let lowerCorner = min(corner, 21)
        let tailTip = CGPoint(x: rect.minX + 1, y: rect.maxY - 4)
        let tailJoin = CGPoint(x: bubbleMinX + 5, y: rect.maxY - 20)

        var path = Path()
        path.move(to: CGPoint(x: bubbleMinX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + corner),
            control1: CGPoint(x: rect.maxX - corner * 0.24, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + corner * 0.24)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - lowerCorner))
        path.addCurve(
            to: CGPoint(x: rect.maxX - lowerCorner, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - lowerCorner * 0.24),
            control2: CGPoint(x: rect.maxX - lowerCorner * 0.24, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: bubbleMinX + lowerCorner + 8, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: bubbleMinX + 7, y: rect.maxY - 1.4),
            control1: CGPoint(x: bubbleMinX + 21, y: rect.maxY),
            control2: CGPoint(x: bubbleMinX + 12, y: rect.maxY + 0.1)
        )
        path.addCurve(
            to: tailTip,
            control1: CGPoint(x: bubbleMinX + 4.3, y: rect.maxY + 0.2),
            control2: CGPoint(x: rect.minX + 2.6, y: rect.maxY - 0.3)
        )
        path.addCurve(
            to: tailJoin,
            control1: CGPoint(x: rect.minX + 5.8, y: rect.maxY - 8.4),
            control2: CGPoint(x: bubbleMinX + 2.8, y: rect.maxY - 15.6)
        )
        path.addCurve(
            to: CGPoint(x: bubbleMinX, y: rect.maxY - lowerCorner),
            control1: CGPoint(x: bubbleMinX + 1.8, y: rect.maxY - 23.6),
            control2: CGPoint(x: bubbleMinX, y: rect.maxY - lowerCorner + 7)
        )
        path.addLine(to: CGPoint(x: bubbleMinX, y: rect.minY + corner))
        path.addCurve(
            to: CGPoint(x: bubbleMinX + corner, y: rect.minY),
            control1: CGPoint(x: bubbleMinX, y: rect.minY + corner * 0.24),
            control2: CGPoint(x: bubbleMinX + corner * 0.24, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
