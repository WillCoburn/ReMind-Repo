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
            title: "Welcome in!",
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
    @State private var bob = false
    @State private var sunrise = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.10))
                .frame(width: 240, height: 240)

            Capsule()
                .fill(Color.figmaBlue.opacity(0.18))
                .frame(width: 176, height: 12)
                .offset(y: 42)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 255/255, green: 244/255, blue: 191/255), Color.figmaBlue.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 94, height: 94)
                .offset(y: sunrise ? -2 : 22)
                .shadow(color: Color.figmaBlue.opacity(0.25), radius: 16, x: 0, y: 6)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: sunrise)

            Path { path in
                path.move(to: CGPoint(x: 84, y: 153))
                path.addQuadCurve(to: CGPoint(x: 216, y: 153), control: CGPoint(x: 150, y: 122))
            }
            .stroke(Color.figmaBlue.opacity(0.55), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .offset(y: bob ? -2 : 2)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: bob)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            bob = true
            sunrise = true
        }
    }
}

private struct ExportTourIllustration: View {
    @State private var bob = false
    @State private var cursorVisible = false
    @State private var lineProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.08))
                .frame(width: 230, height: 230)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 238/255, green: 246/255, blue: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 230, height: 170)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
                .offset(y: bob ? -6 : 6)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bob)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .frame(width: 170, height: 122)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                Capsule()
                    .fill(Color.figmaBlue.opacity(0.12))
                    .frame(width: 108, height: 7)

                ForEach(0..<2, id: \.self) { idx in
                    Capsule()
                        .fill(Color.figmaBlue.opacity(0.14))
                        .frame(width: 132, height: 7)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.figmaBlue.opacity(0.55))
                                .frame(width: max(0, 126 * lineProgress - CGFloat(idx * 46)), height: 7)
                        }
                }

                Rectangle()
                    .fill(cursorVisible ? Color.figmaBlue.opacity(0.95) : .clear)
                    .frame(width: 2, height: 16)
                    .offset(x: min(126, 126 * lineProgress), y: -3)
            }
            .frame(width: 140, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            bob = true
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                lineProgress = 1
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                cursorVisible.toggle()
            }
        }
    }
}

private struct ReminderTourIllustration: View {
    @State private var bob = false
    @State private var tilt = false
    @State private var waveOffset1: CGFloat = -28
    @State private var waveOffset2: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.10))
                .frame(width: 230, height: 230)
            WaveStrip(width: 248, amplitude: 7, phase: waveOffset1, color: Color.figmaBlue.opacity(0.34))
                .offset(y: 34)
            WaveStrip(width: 242, amplitude: 6, phase: waveOffset2, color: Color.figmaBlue.opacity(0.20))
                .offset(y: 48)

            BottleSilhouette()
                .fill(Color.white)
                .frame(width: 110, height: 164)
                .overlay(
                    BottleSilhouette()
                        .stroke(Color.figmaBlue.opacity(0.40), lineWidth: 2)
                )
                .overlay {
                    VStack(spacing: 5) {
                        Capsule().fill(Color.figmaBlue.opacity(0.20)).frame(width: 44, height: 6)
                        Capsule().fill(Color.figmaBlue.opacity(0.16)).frame(width: 40, height: 6)
                        Capsule().fill(Color.figmaBlue.opacity(0.12)).frame(width: 28, height: 6)
                    }
                    .offset(y: 26)
                }
                .rotationEffect(.degrees(tilt ? 6 : -6))
                .offset(y: bob ? -7 : 7)
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 7)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: tilt)
                .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: bob)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            bob = true
            tilt = true
            waveOffset1 = 26
            waveOffset2 = -24
        }
        .animation(.linear(duration: 3.3).repeatForever(autoreverses: true), value: waveOffset1)
        .animation(.linear(duration: 3.8).repeatForever(autoreverses: true), value: waveOffset2)
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

private struct BottleSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let neckWidth = rect.width * 0.22
        let neckX = rect.midX - neckWidth / 2
        let shoulderY = rect.height * 0.26
        let bodyBottom = rect.height * 0.95

        path.move(to: CGPoint(x: neckX, y: rect.height * 0.02))
        path.addLine(to: CGPoint(x: neckX, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.45),
            control: CGPoint(x: rect.width * 0.22, y: rect.height * 0.31)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.22, y: bodyBottom),
            control: CGPoint(x: rect.width * 0.06, y: rect.height * 0.72)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.78, y: bodyBottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.45),
            control: CGPoint(x: rect.width * 0.94, y: rect.height * 0.72)
        )
        path.addQuadCurve(
            to: CGPoint(x: neckX + neckWidth, y: shoulderY),
            control: CGPoint(x: rect.width * 0.78, y: rect.height * 0.31)
        )
        path.addLine(to: CGPoint(x: neckX + neckWidth, y: rect.height * 0.02))
        path.closeSubpath()
        return path
    }
}

private struct WaveStrip: View {
    let width: CGFloat
    let amplitude: CGFloat
    let phase: CGFloat
    let color: Color

    var body: some View {
        Path { path in
            let baseline: CGFloat = 0
            path.move(to: CGPoint(x: 0, y: baseline))
            for x in stride(from: 0, through: width, by: 3) {
                let progress = x / width
                let y = sin(progress * .pi * 2 + phase) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        .frame(width: width, height: 24)
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
