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
            message: "Nice job being kinder to yourself.",
            imageName: nil,
            textAlignment: .center
        ),
        .init(
            step: .export,
            title: "Think of this app as a micro-journal for flashes of clarity, positivity, or whatever inspires you.",
            message: "",
            imageName: nil,
            textAlignment: .center
        ),
        .init(
            step: .reminders,
            title: "A few times a week, an entry will be texted back to you to keep you grounded in your best headspace. Sometimes they come when you need it most.",
            message: "",
            imageName: nil,
            textAlignment: .center
        ),
        .init(
            step: .sendNow,
            title: "",
            message: "If you have some positivity to share, the community page is the place to uplift others.",
            imageName: nil,
            textAlignment: .center
        ),
        .init(
            step: .phoneNumber,
            title: "heads up! We are about to ask for your phone number.",
            message: "We never share it or use it for spam — it’s only used to send your own entries back to you.",
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
        ZStack {
            // OPAQUE, LIGHT BLUE-TINTED BACKGROUND
            Color(red: 244/255, green: 248/255, blue: 255/255)
                .ignoresSafeArea()

            VStack(spacing: 24) {

                // Skip Button Row
                HStack {
                    Spacer()
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.headline)
                            .foregroundColor(.figmaBlue)
                    }
                }
                .padding(.top, 8)

                // MARK: - TabView
                TabView(selection: $step) {
                    ForEach(pages) { page in
                        FeatureTourPageView(page: page)
                            .tag(page.step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))   // custom dots instead
                .animation(.easeInOut(duration: 0.25), value: step)

                // MARK: - Progress Dots
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
                .padding(.bottom, 4)
                .animation(.easeInOut(duration: 0.25), value: step)

                // MARK: - Final Button
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
                    .padding(.horizontal, 8)
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.light)
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
        VStack(spacing: 24) {
            Spacer()

            if isTextAboveImage {
                textBlock
                illustration
            } else {
                illustration
                textBlock
            }

            Spacer()
        }
        .padding(.top, 16)
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
            maxWidth: .infinity,
            alignment: Alignment(
                horizontal: page.textAlignment,
                vertical: .center
            )
        )
    }

    @ViewBuilder
    private var titleText: some View {
        switch page.step {
        case .export:
            (
                Text("Think of this app as a ")
                + Text("micro-journal for flashes of clarity, positivity, or whatever inspires you.").bold()
            )
            .font(.title2.weight(.semibold))
        case .reminders:
            (
                Text("A few times a week, an entry ")
                + Text("will be texted back to you to keep you grounded").bold()
                + Text(" in your best headspace. Sometimes they come when you need it most.")
            )
            .font(.title2.weight(.semibold))
        case .phoneNumber:
            Text(page.title)
                .font(.title2.weight(.semibold))
        default:
            Text(page.title)
                .font(.title2.weight(.semibold))
        }
    }

    @ViewBuilder
    private var messageText: some View {
        switch page.step {
        case .sendNow:
            (
                Text("If you have some positivity to share, the ")
                + Text("community page is the place to uplift others").bold()
                + Text(".")
            )
            .font(.title3.weight(.semibold))
            .foregroundColor(.secondary)
        default:
            Text(page.message)
                .font(.body)
                .foregroundColor(.secondary)
        }
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
    @State private var cheerBounce = false
    @State private var blinkEyes = false
    @State private var smilePulse = false
    @State private var sparklePop = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.08))
                .frame(width: 240, height: 240)

            HStack(spacing: 112) {
                Circle()
                    .fill(Color.figmaBlue.opacity(0.95))
                    .frame(width: 16, height: 16)
                    .scaleEffect(x: 1.0, y: blinkEyes ? 0.12 : 1.0, anchor: .center)
                    .offset(y: 10)

                Circle()
                    .fill(Color.figmaBlue.opacity(0.95))
                    .frame(width: 16, height: 16)
                    .scaleEffect(x: 1.0, y: blinkEyes ? 0.12 : 1.0, anchor: .center)
                    .offset(y: 10)
            }
            .offset(y: -2)

            BrainMascotShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 160/255, green: 202/255, blue: 1),
                            Color(red: 117/255, green: 174/255, blue: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 156, height: 132)
                .overlay {
                    BrainMascotShape()
                        .stroke(Color.figmaBlue.opacity(0.35), lineWidth: 2)
                }
                .overlay {
                    BrainGroovesShape()
                        .stroke(Color.figmaBlue.opacity(0.26), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                }
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
                .offset(y: cheerBounce ? -7 : 7)
                .animation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true), value: cheerBounce)
                .overlay {
                    HStack(spacing: 24) {
                        Circle().fill(Color.figmaBlue).frame(width: 8, height: 8)
                        Circle().fill(Color.figmaBlue).frame(width: 8, height: 8)
                    }
                    .offset(y: -10)
                }
                .overlay {
                    SmileArc()
                        .stroke(Color.figmaBlue, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                        .frame(width: 52, height: 26)
                        .scaleEffect(smilePulse ? 1.05 : 0.96)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: smilePulse)
                        .offset(y: 16)
                }

            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.figmaBlue.opacity(0.6))
                .scaleEffect(sparklePop ? 1.0 : 0.7)
                .offset(x: -72, y: -62)
                .animation(.spring(response: 0.45, dampingFraction: 0.6).repeatForever(autoreverses: true), value: sparklePop)

            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.figmaBlue.opacity(0.52))
                .scaleEffect(sparklePop ? 1.0 : 0.76)
                .offset(x: 74, y: -50)
                .animation(.spring(response: 0.45, dampingFraction: 0.6).repeatForever(autoreverses: true).delay(0.1), value: sparklePop)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            cheerBounce = true
            smilePulse = true
            sparklePop = true
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(.easeInOut(duration: 0.08)) {
                    blinkEyes = true
                }
                try? await Task.sleep(for: .seconds(0.11))
                withAnimation(.easeInOut(duration: 0.08)) {
                    blinkEyes = false
                }
            }
        }
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

private struct BrainMascotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        return path
    }
}

private struct BrainGroovesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.26, y: rect.height * 0.18))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.84),
            control: CGPoint(x: rect.width * 0.18, y: rect.height * 0.52)
        )
        path.move(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.12))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.88),
            control: CGPoint(x: rect.width * 0.62, y: rect.height * 0.52)
        )
        path.move(to: CGPoint(x: rect.width * 0.74, y: rect.height * 0.18))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.7, y: rect.height * 0.84),
            control: CGPoint(x: rect.width * 0.82, y: rect.height * 0.52)
        )
        return path
    }
}

private struct SmileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
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

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.figmaBlue.opacity(index == 1 ? 0.9 : 0.4))
                            .frame(width: 6, height: 6)
                    }
                }
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

private struct CommunityTourIllustration: View {
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
