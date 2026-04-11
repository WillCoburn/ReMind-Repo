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
    @State private var sproutGrow = false
    @State private var leafWiggle = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.08))
                .frame(width: 240, height: 240)
                .scaleEffect(pulse ? 1.02 : 0.95)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)

            Ellipse()
                .fill(Color.figmaBlue.opacity(0.14))
                .frame(width: 138, height: 18)
                .offset(y: 78)

            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 183/255, green: 137/255, blue: 94/255),
                            Color(red: 151/255, green: 107/255, blue: 68/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 126, height: 95)
                .offset(y: 28)
                .overlay {
                    RoundedRectangle(cornerRadius: 46, style: .continuous)
                        .stroke(Color.black.opacity(0.10), lineWidth: 1)
                        .offset(y: 28)
                }

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 112/255, green: 194/255, blue: 106/255),
                            Color(red: 86/255, green: 171/255, blue: 90/255)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 12, height: sproutGrow ? 88 : 26)
                .offset(y: sproutGrow ? -10 : 16)
                .animation(.spring(response: 1.0, dampingFraction: 0.7).repeatForever(autoreverses: true), value: sproutGrow)

            LeafShape()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 146/255, green: 222/255, blue: 130/255), Color(red: 96/255, green: 186/255, blue: 105/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 34)
                .overlay {
                    LeafShape()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
                }
                .rotationEffect(.degrees(leafWiggle ? -15 : -27))
                .offset(x: -21, y: -46)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: leafWiggle)

            LeafShape()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 133/255, green: 211/255, blue: 124/255), Color(red: 90/255, green: 177/255, blue: 99/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 36)
                .overlay {
                    LeafShape()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
                }
                .rotationEffect(.degrees(leafWiggle ? 23 : 12))
                .offset(x: 22, y: -48)
                .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: leafWiggle)

            ForEach(0..<3, id: \.self) { idx in
                SparkleMark()
                    .fill(Color(red: 255/255, green: 232/255, blue: 161/255).opacity(0.95))
                    .frame(width: idx % 2 == 0 ? 10 : 7, height: idx % 2 == 0 ? 10 : 7)
                    .offset(
                        x: [52.0, 10.0, -42.0][idx] + (leafWiggle ? [5.0, 3.0, 4.0][idx] : 0),
                        y: [-52.0, -78.0, -58.0][idx] + (leafWiggle ? [-4.0, 2.0, -3.0][idx] : 0)
                    )
                    .opacity(leafWiggle ? 0.95 : 0.3)
                    .animation(
                        .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(idx) * 0.15),
                        value: leafWiggle
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            sproutGrow = true
            leafWiggle = true
            pulse = true
        }
    }
}

private struct ExportTourIllustration: View {
    @State private var pageTurn = false
    @State private var penWrite = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.08))
                .frame(width: 230, height: 230)
                .scaleEffect(pulse ? 1.01 : 0.95)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 74/255, green: 114/255, blue: 208/255).opacity(0.92))
                .frame(width: 170, height: 210)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.24))
                        .frame(width: 8, height: 184)
                        .padding(.leading, 12)
                }
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 244/255, green: 249/255, blue: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 130, height: 178)
                .offset(x: 12, y: 4)
                .overlay(alignment: .topTrailing) {
                    FoldedCorner()
                        .fill(Color(red: 222/255, green: 233/255, blue: 255/255))
                        .frame(width: 22, height: 22)
                        .offset(x: 1, y: 0)
                        .rotationEffect(.degrees(pageTurn ? 0 : -8))
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pageTurn)
                }
                .overlay {
                    VStack(alignment: .leading, spacing: 10) {
                        Capsule().fill(Color.figmaBlue.opacity(0.18)).frame(width: 76, height: 6)
                        Capsule().fill(Color.figmaBlue.opacity(0.22)).frame(width: 92, height: 6)
                        Capsule().fill(Color.figmaBlue.opacity(0.20)).frame(width: 88, height: 6)
                        Capsule().fill(Color.figmaBlue.opacity(0.20)).frame(width: 70, height: 6)
                    }
                    .offset(x: 3, y: 7)
                }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 240/255, green: 108/255, blue: 118/255))
                .frame(width: 9, height: 44)
                .offset(x: 80, y: 56)

            JournalPen()
                .fill(Color.figmaBlue.opacity(0.88))
                .frame(width: 64, height: 15)
                .overlay {
                    JournalPen()
                        .stroke(Color.white.opacity(0.72), lineWidth: 0.9)
                }
                .rotationEffect(.degrees(-24 + (penWrite ? 5 : -4)))
                .offset(x: penWrite ? 36 : 8, y: penWrite ? 16 : -1)
                .animation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true), value: penWrite)

            Path { path in
                path.move(to: CGPoint(x: -12, y: 12))
                path.addQuadCurve(to: CGPoint(x: 32, y: 18), control: CGPoint(x: 12, y: 0))
            }
            .stroke(Color.figmaBlue.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .offset(x: 14, y: penWrite ? 0 : 9)
            .animation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true), value: penWrite)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            pageTurn = true
            penWrite = true
            pulse = true
        }
    }
}

private struct ReminderTourIllustration: View {
    @State private var driftSlow = false
    @State private var driftFast = false
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
                SineWaveLine(amplitude: 9, frequency: 1.15, color: Color(red: 100/255, green: 162/255, blue: 235/255).opacity(0.50), lineWidth: 4)
                    .offset(x: driftFast ? 38 : -38)
                    .animation(.linear(duration: 3.8).repeatForever(autoreverses: true), value: driftFast)
                SineWaveLine(amplitude: 6, frequency: 1.55, color: Color(red: 155/255, green: 202/255, blue: 250/255).opacity(0.45), lineWidth: 3)
                    .offset(x: driftSlow ? 34 : -34)
                    .animation(.linear(duration: 5.1).repeatForever(autoreverses: true), value: driftSlow)
            }
            .frame(width: 250)
            .offset(y: 44)

            OceanBottleShape()
                .fill(Color(red: 196/255, green: 231/255, blue: 1).opacity(0.28))
                .frame(width: 108, height: 188)
                .overlay {
                    OceanBottleShape()
                        .stroke(Color.figmaBlue.opacity(0.42), lineWidth: 2.1)
                }
                .overlay {
                    OceanBottleShape()
                        .trim(from: 0.06, to: 0.40)
                        .stroke(Color.white.opacity(0.74), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .blur(radius: 0.2)
                }
                .overlay {
                    OceanBottleShape()
                        .trim(from: 0.62, to: 0.87)
                        .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(red: 173/255, green: 123/255, blue: 76/255))
                        .frame(width: 28, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color(red: 120/255, green: 79/255, blue: 48/255).opacity(0.65), lineWidth: 1)
                        )
                        .offset(y: 11)
                }
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(red: 250/255, green: 244/255, blue: 228/255).opacity(0.98))
                            .frame(width: 54, height: 32)
                            .rotationEffect(.degrees(-16))
                            .overlay {
                                VStack(alignment: .leading, spacing: 3) {
                                    Capsule().fill(Color.figmaBlue.opacity(0.35)).frame(width: 26, height: 3)
                                    Capsule().fill(Color.figmaBlue.opacity(0.26)).frame(width: 18, height: 3)
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
            driftFast = true
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

            ForEach([
                (x: -82.0, y: -52.0),
                (x: 84.0, y: -36.0),
                (x: -74.0, y: 56.0),
                (x: 76.0, y: 62.0)
            ], id: \.x) { point in
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

private struct OceanBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let neckWidth = rect.width * 0.18
        let neckX = rect.midX - neckWidth / 2
        let lipY = rect.height * 0.08
        let shoulderY = rect.height * 0.22
        let bellyY = rect.height * 0.60
        let baseY = rect.height * 0.94

        path.move(to: CGPoint(x: neckX, y: lipY))
        path.addLine(to: CGPoint(x: neckX, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.22, y: bellyY),
            control: CGPoint(x: rect.width * 0.20, y: rect.height * 0.40)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.34, y: baseY),
            control: CGPoint(x: rect.width * 0.18, y: rect.height * 0.86)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.66, y: baseY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.78, y: bellyY),
            control: CGPoint(x: rect.width * 0.82, y: rect.height * 0.86)
        )
        path.addQuadCurve(
            to: CGPoint(x: neckX + neckWidth, y: shoulderY),
            control: CGPoint(x: rect.width * 0.80, y: rect.height * 0.40)
        )
        path.addLine(to: CGPoint(x: neckX + neckWidth, y: lipY))
        path.closeSubpath()
        return path
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY)
        )
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
