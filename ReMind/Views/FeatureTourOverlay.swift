// ================================
// File: Views/FeatureTourOverlay.swift
// ================================
import SwiftUI

struct FeatureTourOverlay: View {

    @Binding var step: AppViewModel.FeatureTourStep
    let onComplete: () -> Void
    let onSkip: () -> Void

    // MARK: - Pages for TabView
    private let pages: [FeatureTourPage] = [
        .init(
            step: .settings,
            title: "Welcome!",
            message: "Nice job planting a seed of self-kindness.",
            imageName: nil,
            textAlignment: .center
        ),
        .init(
            step: .export,
            title: "Use this app as a micro-journal for flashes of clarity, positivity, or anything else that inspires you.",
            message: "",
            imageName: nil,
            textAlignment: .center
        ),
        .init(
            step: .reminders,
            title: "Entries will come back via SMS to nudge you back into that headspace.",
            message: "",
            imageName: nil,
            textAlignment: .center
        ),
        .init(
            step: .sendNow,
            title: "Use the community page to share with and uplift others.",
            message: "",
            imageName: nil,
            textAlignment: .center
        ),
        .init(
            step: .phoneNumber,
            title: "But first, we have to ask for your digits.",
            message: "We will NEVER share your number or use it for spam — it’s only used to send your own entries back to you.",
            imageName: nil,
            textAlignment: .center
        )
    ]

    private var isOnLastPage: Bool { step == .phoneNumber }
    private var orderedSteps: [AppViewModel.FeatureTourStep] { pages.map { $0.step } }
    private var currentIndex: Int { orderedSteps.firstIndex(of: step) ?? 0 }
    private var totalPages: Int { pages.count }

    // MARK: - Body
    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = OnboardingLayout.pageHorizontal(for: proxy.size.width)
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let overlayWidth = max(0, proxy.size.width - horizontalPadding * 2)

            ZStack {
                // OPAQUE, LIGHT BLUE-TINTED BACKGROUND
                Color(red: 244/255, green: 248/255, blue: 255/255)
                    .ignoresSafeArea()

                TabView(selection: $step) {
                    ForEach(pages) { page in
                        FeatureTourPageView(page: page)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, topInset + 72)
                            .padding(.bottom, bottomInset + (isOnLastPage ? 150 : 96))
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .tag(page.step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))   // custom dots instead
                .animation(.easeInOut(duration: 0.25), value: step)

                VStack {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.headline)
                            .foregroundColor(.figmaBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .frame(width: overlayWidth, alignment: .trailing)
                    .padding(.top, topInset + 6)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(spacing: 18) {
                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { idx in
                            Circle()
                                .frame(width: 8, height: 8)
                                .foregroundColor(
                                    idx == currentIndex
                                    ? Color.figmaBlue
                                    : Color.figmaBlue.opacity(0.3)
                                )
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: step)

                    if isOnLastPage {
                        Button(action: onComplete) {
                            Text("Get started!")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.figmaBlue)
                                .cornerRadius(14)
                        }
                        .frame(maxWidth: OnboardingLayout.maxContentWidth)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomInset + 24)
            }
        }
        .preferredColorScheme(.light)
        .dynamicTypeSize(.xSmall ... .xxLarge)
    }
}

// ================================
// MARK: - Page Model
// ================================
private struct FeatureTourPage: Identifiable {
    let id: AppViewModel.FeatureTourStep
    let step: AppViewModel.FeatureTourStep
    let title: String
    let message: String
    let imageName: String?
    let textAlignment: HorizontalAlignment

    init(step: AppViewModel.FeatureTourStep,
         title: String,
         message: String,
         imageName: String?,
         textAlignment: HorizontalAlignment) {

        self.id = step
        self.step = step
        self.title = title
        self.message = message
        self.imageName = imageName
        self.textAlignment = textAlignment
    }
}

// ================================
// MARK: - Individual Page View
// ================================
private struct FeatureTourPageView: View {
    let page: FeatureTourPage

    private var isTextAboveImage: Bool {
        // First page has copy at top, image below
        page.step == .settings
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 0)

                    if isTextAboveImage {
                        textBlock
                        illustration
                    } else {
                        illustration
                        textBlock
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: OnboardingLayout.maxContentWidth)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var textBlock: some View {
        VStack(alignment: page.textAlignment, spacing: 12) {
            titleText
                .multilineTextAlignment(
                    page.textAlignment == .center ? .center : .leading
                )

            if !page.message.isEmpty {
                messageText
                    .multilineTextAlignment(
                        page.textAlignment == .center ? .center : .leading
                    )
            }
        }
        .frame(
            maxWidth: OnboardingLayout.maxTourTextWidth,
            alignment: Alignment(
                horizontal: page.textAlignment,
                vertical: .center
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private var titleText: some View {
        Text(page.title)
            .font(.title2.weight(.semibold))
            .lineLimit(nil)
            .minimumScaleFactor(0.9)
    }

    private var messageText: some View {
        Text(page.message)
            .font(.body)
            .foregroundColor(.secondary)
            .lineLimit(nil)
            .minimumScaleFactor(0.9)
    }

    private var illustration: some View {
        Group {
            switch page.step {
            case .settings:
                WelcomeTourIllustration()
            case .export:
                ExportTourIllustration()
            case .reminders:
                ReminderTourIllustration()
            case .sendNow:
                CommunityTourIllustration()
            case .phoneNumber:
                PhoneNumberTourIllustration()
            }
            if let imageName = page.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct WelcomeTourIllustration: View {
    @State private var glowPulse = false
    @State private var seedDropped = false
    @State private var seedHidden = false
    @State private var stemGrown = false
    @State private var leavesStageOne = false
    @State private var leavesStageTwo = false
    @State private var bloomVisible = false
    @State private var idleBreathing = false
    @State private var animationRunID = UUID()

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.08))
                .frame(width: 240, height: 240)
                .scaleEffect(glowPulse ? 1.03 : 0.95)
                .animation(
                    .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: glowPulse
                )

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 168/255, green: 121/255, blue: 90/255),
                            Color(red: 139/255, green: 95/255, blue: 68/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 152, height: 56)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 6)
                .offset(y: 62)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 140/255, green: 204/255, blue: 126/255),
                            Color(red: 94/255, green: 170/255, blue: 102/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 8, height: 104)
                .scaleEffect(y: stemGrown ? 1 : 0.02, anchor: .bottom)
                .offset(y: 10)
                .shadow(color: Color.green.opacity(0.2), radius: 4, x: 0, y: 2)

            Group {
                SeedLeafShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 139/255, green: 210/255, blue: 123/255), Color(red: 95/255, green: 179/255, blue: 110/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        SeedLeafShape()
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                            .scaleEffect(x: 0.72, y: 0.18, anchor: .leading)
                            .offset(x: 4, y: -1)
                    )
                    .frame(width: 44, height: 24)
                    .rotationEffect(.degrees(-31))
                    .offset(x: -24, y: -2)
                    .opacity(leavesStageOne ? 1 : 0)
                    .scaleEffect(leavesStageOne ? 1 : 0.2, anchor: .trailing)

                SeedLeafShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 145/255, green: 214/255, blue: 128/255), Color(red: 102/255, green: 182/255, blue: 112/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        SeedLeafShape()
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                            .scaleEffect(x: 0.72, y: 0.18, anchor: .leading)
                            .offset(x: 4, y: -1)
                    )
                    .frame(width: 44, height: 24)
                    .rotationEffect(.degrees(31))
                    .offset(x: 24, y: -10)
                    .opacity(leavesStageOne ? 1 : 0)
                    .scaleEffect(leavesStageOne ? 1 : 0.2, anchor: .leading)

                SeedLeafShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 156/255, green: 218/255, blue: 136/255), Color(red: 108/255, green: 188/255, blue: 118/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        SeedLeafShape()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            .scaleEffect(x: 0.68, y: 0.16, anchor: .leading)
                            .offset(x: 3, y: -1)
                    )
                    .frame(width: 32, height: 18)
                    .rotationEffect(.degrees(-32))
                    .offset(x: -17, y: -41)
                    .opacity(leavesStageTwo ? 1 : 0)
                    .scaleEffect(leavesStageTwo ? 1 : 0.2, anchor: .trailing)

                SeedLeafShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 146/255, green: 209/255, blue: 127/255), Color(red: 98/255, green: 176/255, blue: 110/255)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        SeedLeafShape()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            .scaleEffect(x: 0.68, y: 0.16, anchor: .leading)
                            .offset(x: 3, y: -1)
                    )
                    .frame(width: 30, height: 17)
                    .rotationEffect(.degrees(35))
                    .offset(x: 18, y: -34)
                    .opacity(leavesStageTwo ? 1 : 0)
                    .scaleEffect(leavesStageTwo ? 1 : 0.2, anchor: .leading)
            }
            .offset(y: 8)

            SimpleBloomShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 231/255, green: 198/255, blue: 222/255),
                            Color(red: 212/255, green: 174/255, blue: 203/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.42))
                        .frame(width: 9, height: 9)
                )
                .frame(width: 60, height: 60)
                .offset(y: -60)
                .opacity(bloomVisible ? 1 : 0)
                .scaleEffect(bloomVisible ? 1 : 0.25)
                .shadow(color: Color(red: 180/255, green: 130/255, blue: 168/255).opacity(0.18), radius: 3, x: 0, y: 1)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 128/255, green: 94/255, blue: 68/255),
                            Color(red: 108/255, green: 76/255, blue: 56/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 12, height: 12)
                .opacity(seedHidden ? 0 : 1)
                .offset(y: seedDropped ? 66 : -34)
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                .animation(.easeInOut(duration: 0.56), value: seedDropped)
                .animation(.easeOut(duration: 0.20), value: seedHidden)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .scaleEffect(idleBreathing ? 1.01 : 0.99)
        .offset(y: idleBreathing ? -1.5 : 1.5)
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: idleBreathing)
        .onAppear {
            let runID = UUID()
            animationRunID = runID
            resetAnimationState()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard animationRunID == runID else { return }
                startAnimationSequence(runID: runID)
            }
        }
        .onDisappear {
            animationRunID = UUID()
        }
    }

    private func resetAnimationState() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            glowPulse = false
            seedDropped = false
            seedHidden = false
            stemGrown = false
            leavesStageOne = false
            leavesStageTwo = false
            bloomVisible = false
            idleBreathing = false
        }
    }

    private func startAnimationSequence(runID: UUID) {
        glowPulse = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            guard animationRunID == runID else { return }
            seedDropped = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            guard animationRunID == runID else { return }
            seedHidden = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
            guard animationRunID == runID else { return }
            withAnimation(.easeOut(duration: 0.84)) {
                stemGrown = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.18) {
            guard animationRunID == runID else { return }
            withAnimation(.easeOut(duration: 0.42)) {
                leavesStageOne = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.48) {
            guard animationRunID == runID else { return }
            withAnimation(.easeOut(duration: 0.40)) {
                leavesStageTwo = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.78) {
            guard animationRunID == runID else { return }
            withAnimation(.easeOut(duration: 0.32)) {
                bloomVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.08) {
            guard animationRunID == runID else { return }
            idleBreathing = true
        }
    }
}

private struct SeedLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let base = CGPoint(x: rect.minX, y: rect.midY)
        let tip = CGPoint(x: rect.maxX, y: rect.midY)
        path.move(to: base)
        path.addCurve(
            to: tip,
            control1: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY - rect.height * 0.08),
            control2: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.06)
        )
        path.addCurve(
            to: base,
            control1: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.maxY - rect.height * 0.06),
            control2: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY + rect.height * 0.08)
        )
        return path
    }
}

private struct SimpleBloomShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let petalRadius = min(rect.width, rect.height) * 0.22
        let ringRadius = min(rect.width, rect.height) * 0.26

        let offsets = [
            CGPoint(x: 0, y: -ringRadius),
            CGPoint(x: ringRadius, y: 0),
            CGPoint(x: 0, y: ringRadius),
            CGPoint(x: -ringRadius, y: 0),
            CGPoint(x: 0, y: 0)
        ]

        for offset in offsets {
            let petalRect = CGRect(
                x: center.x + offset.x - petalRadius,
                y: center.y + offset.y - petalRadius,
                width: petalRadius * 2,
                height: petalRadius * 2
            )
            path.addEllipse(in: petalRect)
        }

        return path
    }
}

private struct ExportTourIllustration: View {
    @State private var pulse = false
    @State private var penWiggle = false
    @State private var bulbGlow = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.08))
                .frame(width: 230, height: 230)
                .scaleEffect(pulse ? 1.01 : 0.95)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 246/255, green: 250/255, blue: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 148, height: 194)
                .overlay {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule().fill(Color.figmaBlue.opacity(0.18)).frame(width: 108, height: 5)
                        }
                    }
                    .offset(x: 0, y: 16)
                }
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 232/255, green: 239/255, blue: 1))
                        .frame(width: 8, height: 170)
                        .offset(x: 6)
                }
                .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 8)

            JournalPen()
                .fill(Color.figmaBlue.opacity(0.88))
                .frame(width: 64, height: 15)
                .overlay {
                    JournalPen()
                        .stroke(Color.white.opacity(0.72), lineWidth: 0.9)
                }
                .rotationEffect(.degrees(-24 + (penWiggle ? 2.0 : -2.0)))
                .offset(
                    x: -6 + (penWiggle ? 4.0 : -4.0),
                    y: 18 + (penWiggle ? 1.0 : -1.0)
                )
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: penWiggle)

            Image(systemName: "lightbulb.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 214/255, blue: 92/255),
                            Color(red: 1.0, green: 186/255, blue: 66/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(bulbGlow ? 1.06 : 0.92)
                .shadow(color: Color(red: 1.0, green: 214/255, blue: 92/255).opacity(bulbGlow ? 0.32 : 0.1), radius: bulbGlow ? 10 : 4)
                .offset(y: -48)
            .animation(.easeInOut(duration: 0.68).repeatForever(autoreverses: true), value: bulbGlow)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            pulse = true
            penWiggle = true
            bulbGlow = true
        }
    }
}

private struct ReminderTourIllustration: View {
    @State private var driftSlow = false
    @State private var bottleBob = false
    @State private var bottleTilt = false
    @State private var noteLag = false
    @State private var glintSweep = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.10))
                .frame(width: 240, height: 240)

            VStack(spacing: 8) {
                SineWaveLine(amplitude: 7, frequency: 1.35, color: Color(red: 78/255, green: 135/255, blue: 226/255).opacity(0.68), lineWidth: 5)
                    .offset(x: driftSlow ? -30 : 30)
                    .animation(.linear(duration: 4.6).repeatForever(autoreverses: true), value: driftSlow)
            }
            .frame(width: 250)
            .offset(y: 24)

            OceanBottleShape()
                .fill(Color(red: 196/255, green: 231/255, blue: 1).opacity(0.28))
                .frame(width: 108, height: 188)
                .overlay {
                    OceanBottleShape()
                        .stroke(Color.figmaBlue.opacity(0.62), lineWidth: 2.5)
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(red: 173/255, green: 123/255, blue: 76/255))
                            .frame(width: 24, height: 15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color(red: 120/255, green: 79/255, blue: 48/255).opacity(0.65), lineWidth: 1)
                            )
                        Capsule()
                            .fill(Color(red: 235/255, green: 244/255, blue: 1).opacity(0.9))
                            .frame(width: 21, height: 3)
                    }
                    .offset(y: 10)
                }
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .stroke(Color.white.opacity(0.42), lineWidth: 1.5)
                        .frame(width: 32, height: 8)
                        .offset(y: -6)
                }
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(red: 250/255, green: 244/255, blue: 228/255).opacity(0.98))
                            .frame(width: 48, height: 28)
                            .rotationEffect(.degrees(-16))
                            .overlay {
                                VStack(alignment: .leading, spacing: 3) {
                                    Capsule().fill(Color.figmaBlue.opacity(0.35)).frame(width: 22, height: 2.5)
                                    Capsule().fill(Color.figmaBlue.opacity(0.26)).frame(width: 15, height: 2.5)
                                }
                                .offset(x: -6, y: 1)
                            }
                    }
                    .offset(x: noteLag ? -2 : 2, y: noteLag ? 18 : 14)
                    .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true).delay(0.18), value: noteLag)
                }
                .overlay {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.0), Color.white.opacity(0.42), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 22, height: 210)
                        .rotationEffect(.degrees(16))
                        .offset(x: glintSweep ? 72 : -72, y: -5)
                        .opacity(0.55)
                        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: false), value: glintSweep)
                        .mask {
                            OceanBottleShape()
                        }
                }
                .rotationEffect(.degrees(bottleTilt ? 5 : -5))
                .offset(y: bottleBob ? -8 : 8)
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 7)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: bottleTilt)
                .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: bottleBob)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            driftSlow = true
            bottleBob = true
            bottleTilt = true
            noteLag = true
            glintSweep = true
        }
    }
}

private struct PhoneNumberTourIllustration: View {
    @State private var bob = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.10))
                .frame(width: 220, height: 220)
                .scaleEffect(pulse ? 1.0 : 0.92)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 238/255, green: 246/255, blue: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 140, height: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
                .offset(y: bob ? -5 : 5)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bob)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.figmaBlue.opacity(0.25))
                        .frame(width: 42, height: 5)
                        .padding(.top, 10)
                }

            VStack(spacing: 10) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.figmaBlue)

                Text("(555) 123-4567")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)


            }

            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.figmaBlue)
                    .padding(10)
                    .background(.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)

                Text("Private")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.figmaBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            }
            .offset(x: 95, y: -70)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            bob = true
            pulse = true
        }
    }
}

struct CommunityTourIllustration: View {
    @State private var ripple = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { idx in
                Circle()
                    .stroke(Color.figmaBlue.opacity(0.18 - Double(idx) * 0.04), lineWidth: 2)
                    .frame(width: 122 + CGFloat(idx * 40), height: 122 + CGFloat(idx * 40))
                    .scaleEffect(ripple ? 1.03 : 0.93)
                    .opacity(ripple ? 0.45 : 0.9)
                    .animation(
                        .easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(idx) * 0.18),
                        value: ripple
                    )
            }

            Circle()
                .fill(Color.figmaBlue.opacity(0.15))
                .frame(width: 98, height: 98)
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.figmaBlue)
                        .scaleEffect(pulse ? 1.04 : 0.90)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                }

            ForEach(CommunityAvatarOffset.allCases) { point in
                Image(systemName: "person.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.figmaBlue.opacity(0.85))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .offset(x: point.x, y: point.y)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            ripple = true
            pulse = true
        }
    }
}

private struct CommunityAvatarOffset: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat

    static let allCases: [CommunityAvatarOffset] = [
        .init(id: 0, x: -82, y: -52),
        .init(id: 1, x: 84, y: -36),
        .init(id: 2, x: -74, y: 56),
        .init(id: 3, x: 76, y: 62)
    ]
}

private struct OceanBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let neckWidth = rect.width * 0.14
        let neckX = rect.midX - neckWidth / 2
        let lipY = rect.height * 0.06
        let neckBottomY = rect.height * 0.30
        let shoulderY = rect.height * 0.40
        let widestY = rect.height * 0.74
        let baseY = rect.height * 0.95

        path.move(to: CGPoint(x: neckX, y: lipY))
        path.addLine(to: CGPoint(x: neckX, y: neckBottomY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.24, y: shoulderY),
            control: CGPoint(x: rect.width * 0.28, y: rect.height * 0.36)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.22, y: widestY),
            control: CGPoint(x: rect.width * 0.21, y: rect.height * 0.58)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.33, y: baseY),
            control: CGPoint(x: rect.width * 0.23, y: rect.height * 0.90)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.67, y: baseY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.78, y: widestY),
            control: CGPoint(x: rect.width * 0.77, y: rect.height * 0.90)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.76, y: shoulderY),
            control: CGPoint(x: rect.width * 0.79, y: rect.height * 0.58)
        )
        path.addQuadCurve(
            to: CGPoint(x: neckX + neckWidth, y: neckBottomY),
            control: CGPoint(x: rect.width * 0.72, y: rect.height * 0.36)
        )
        path.addLine(to: CGPoint(x: neckX + neckWidth, y: lipY))
        path.closeSubpath()
        return path
    }
}

private struct FoldedCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SineWaveLine: View {
    let amplitude: CGFloat
    let frequency: CGFloat
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Path { path in
            let baseline: CGFloat = 12
            path.move(to: CGPoint(x: 0, y: baseline))
            for x in stride(from: CGFloat(0), through: 250, by: 2) {
                let progress = x / 250
                let y = baseline + sin(progress * .pi * 2 * frequency) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        .overlay(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: 90, y: 10))
                path.addQuadCurve(to: CGPoint(x: 128, y: 8), control: CGPoint(x: 110, y: 2))
            }
            .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        .frame(width: 250, height: 24)
    }
}

private struct SparkleMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
            .strokedPath(.init(lineWidth: max(1, rect.width * 0.17), lineCap: .round))
    }
}

private struct JournalPen: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.2, width: rect.width * 0.78, height: rect.height * 0.6), cornerSize: CGSize(width: rect.height * 0.3, height: rect.height * 0.3))
        path.move(to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.8))
        path.closeSubpath()
        return path
    }
}

// ================================
// MARK: - Preview
// ================================
#if DEBUG
struct FeatureTourOverlay_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FeatureTourOverlay(
                step: .constant(.settings),
                onComplete: {},
                onSkip: {}
            )
            .previewDisplayName("Settings")

            FeatureTourOverlay(
                step: .constant(.export),
                onComplete: {},
                onSkip: {}
            )
            .previewDisplayName("Export")

            FeatureTourOverlay(
                step: .constant(.sendNow),
                onComplete: {},
                onSkip: {}
            )
            .previewDisplayName("Send Now")

            FeatureTourOverlay(
                step: .constant(.reminders),
                onComplete: {},
                onSkip: {}
            )
            .previewDisplayName("Reminders")

            FeatureTourOverlay(
                step: .constant(.phoneNumber),
                onComplete: {},
                onSkip: {}
            )
            .previewDisplayName("Phone Number")
        }
    }
}
#endif
