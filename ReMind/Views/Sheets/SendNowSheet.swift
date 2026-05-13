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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isCompact ? 18 : 24) {
                        Spacer(minLength: isCompact ? 10 : 24)

                        SendNowIllustration(isSending: isSending, animate: animateIllustration)
                            .frame(height: isCompact ? 180 : 232)
                            .accessibilityHidden(true)

                        VStack(spacing: 10) {
                            Text("Need some of your own wisdom right now?")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(Color.black.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("We’ll pull one saved thought from your journal and text it back like a note from past you.")
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
        }
        .navigationTitle("Send One Now")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
        .onAppear { restartIllustration() }
        .onDisappear { animateIllustration = false }
        .dynamicTypeSize(.xSmall ... .xxLarge)
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
                            Color.figmaBlue.opacity(0.11),
                            Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.16)
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: 132
                    )
                )
                .frame(width: 230, height: 230)
                .scaleEffect(animate ? 1.04 : 0.96)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: animate)

            ArrivalTrailDots(animate: animate)
                .offset(x: -10, y: -8)

            PastSelfNoteCard(animate: animate)
                .offset(x: animate ? -72 : -88, y: animate ? 46 : 54)
                .rotationEffect(.degrees(animate ? -7 : -11))
                .opacity(0.88)
                .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: animate)

            PhoneMessageFrame(animate: animate)
                .offset(x: 36, y: animate ? 6 : 12)
                .rotationEffect(.degrees(animate ? 2 : -1))
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: animate)

            WisdomMessagePreview(isSending: isSending, animate: animate)
                .offset(x: animate ? -4 : -34, y: animate ? -42 : -56)
                .scaleEffect(isSending ? 0.97 : (animate ? 1 : 0.94))
                .opacity(animate ? 1 : 0.72)
                .animation(.spring(response: 0.72, dampingFraction: 0.82), value: animate)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ArrivalTrailDots: View {
    let animate: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index == 4 ? Color.figmaBlue.opacity(0.28) : Color.figmaBlue.opacity(0.14))
                    .frame(width: 7, height: 7)
                    .scaleEffect(animate ? 1 + CGFloat(index) * 0.035 : 0.78)
                    .opacity(animate ? 0.92 - Double(index) * 0.08 : 0.42)
            }
        }
        .rotationEffect(.degrees(-18))
        .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: animate)
    }
}

private struct PhoneMessageFrame: View {
    let animate: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.70))
            .frame(width: 116, height: 174)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.figmaBlue.opacity(0.50), lineWidth: 4)
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.figmaBlue.opacity(0.28))
                    .frame(width: 30, height: 5)
                    .padding(.top, 12)
            }
            .overlay(alignment: .bottom) {
                Circle()
                    .stroke(Color.figmaBlue.opacity(0.20), lineWidth: 2)
                    .frame(width: 11, height: 11)
                    .padding(.bottom, 11)
            }
            .overlay {
                VStack(alignment: .leading, spacing: 7) {
                    Spacer(minLength: 28)
                    MiniIncomingBubble(width: 78, accent: Color.figmaBlue.opacity(0.18))
                    MiniIncomingBubble(width: animate ? 66 : 54, accent: Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.22))
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 13)
            }
            .shadow(color: Color.figmaBlue.opacity(0.12), radius: 18, x: 0, y: 9)
    }
}

private struct MiniIncomingBubble: View {
    let width: CGFloat
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.figmaBlue.opacity(0.34))
                .frame(width: 4, height: 4)
            Capsule()
                .fill(accent)
                .frame(width: max(width - 18, 18), height: 5)
        }
        .padding(.leading, 11)
        .padding(.trailing, 9)
        .padding(.vertical, 8)
        .frame(width: width, alignment: .leading)
        .background(
            SheetIncomingMessageShape()
                .fill(Color.white.opacity(0.82))
        )
    }
}

private struct WisdomMessagePreview: View {
    let isSending: Bool
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.figmaBlue.opacity(isSending ? 0.34 : 0.24))
                    .frame(width: 8, height: 8)

                Text("past you")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.44))
            }

            Capsule()
                .fill(Color.figmaBlue.opacity(isSending ? 0.30 : 0.23))
                .frame(width: 104, height: 7)
            Capsule()
                .fill(Color.figmaBlue.opacity(0.13))
                .frame(width: 142, height: 7)
            Capsule()
                .fill(Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.34))
                .frame(width: animate ? 78 : 52, height: 7)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: animate)
        }
        .padding(.leading, 25)
        .padding(.trailing, 20)
        .padding(.vertical, 16)
        .background(
            SheetIncomingMessageShape()
                .fill(Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(0.075), radius: 15, x: 0, y: 8)
        )
        .overlay {
            SheetIncomingMessageShape()
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        }
    }
}

private struct PastSelfNoteCard: View {
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("saved earlier")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.38))

            Capsule()
                .fill(Color.figmaBlue.opacity(0.20))
                .frame(width: 54, height: 5)
            Capsule()
                .fill(Color.figmaBlue.opacity(0.12))
                .frame(width: 84, height: 5)
            Capsule()
                .fill(Color(red: 130/255, green: 198/255, blue: 184/255).opacity(0.28))
                .frame(width: animate ? 68 : 48, height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(width: 118, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.70))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
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
