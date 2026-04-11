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
            textAlignment: .center
        ),
        .init(
            step: .export,
            title: "Think of this app as a micro-journal for your flashes of clarity and positivity.",
            message: "These things that inspire you will be randomly texted back, hopefully to remind you when you need it most.",
            textAlignment: .center
        ),
        .init(
            step: .sendNow,
            title: "",
            message: "If you have some positivity to share, the community page is the place to uplift others.",
            textAlignment: .center
        ),
        .init(
            step: .phoneNumber,
            title: "Next, we’ll ask for your phone number.",
            message: "We never share it or use it for spam — it’s only used to send your own entries back to you.",
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
                .tabViewStyle(.page(indexDisplayMode: .never))
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
    let textAlignment: HorizontalAlignment

    init(step: AppViewModel.FeatureTourStep,
         title: String,
         message: String,
         textAlignment: HorizontalAlignment) {

        self.id = step
        self.step = step
        self.title = title
        self.message = message
        self.textAlignment = textAlignment
    }
}

// ================================
// MARK: - Individual Page View
// ================================
private struct FeatureTourPageView: View {
    let page: FeatureTourPage

    private var isTextAboveImage: Bool {
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
            Text(page.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(
                    page.textAlignment == .center ? .center : .leading
                )

            if !page.message.isEmpty {
                Text(page.message)
                    .font(.body)
                    .foregroundColor(.secondary)
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
    private var illustration: some View {
        switch page.step {
        case .settings:
            WelcomeTourIllustration()
        case .export:
            JournalTourIllustration()
        case .sendNow:
            CommunityTourIllustration()
        case .phoneNumber:
            PhoneNumberTourIllustration()
        }
    }
}

private struct WelcomeTourIllustration: View {
    @State private var bob = false
    @State private var ring = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.10))
                .frame(width: 240, height: 240)
                .scaleEffect(ring ? 1.02 : 0.92)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: ring)

            Circle()
                .fill(.white)
                .frame(width: 160, height: 160)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
                .overlay(
                    Circle()
                        .stroke(Color.figmaBlue.opacity(0.25), lineWidth: 1)
                )
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.figmaBlue)
                }
                .offset(y: bob ? -6 : 6)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: bob)

            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                Image(systemName: "sun.max.fill")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.figmaBlue.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
            .offset(y: 95)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            bob = true
            ring = true
        }
    }
}

private struct JournalTourIllustration: View {
    @State private var floatCard = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.figmaBlue.opacity(0.10))
                .frame(width: 250, height: 230)
                .scaleEffect(pulse ? 1 : 0.95)
                .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: pulse)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(Color.figmaBlue).frame(width: 8, height: 8)
                    Text("Moment captured")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.figmaBlue)
                }

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.figmaBlue.opacity(0.22))
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.figmaBlue.opacity(0.14))
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.figmaBlue.opacity(0.18))
                    .frame(height: 10)

                HStack {
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.figmaBlue)
                }
            }
            .padding(20)
            .frame(width: 220)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.09), radius: 14, x: 0, y: 8)
            .offset(y: floatCard ? -6 : 7)
            .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: floatCard)

            HStack(spacing: 10) {
                Text("Sent back later")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.figmaBlue)
                Image(systemName: "message.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.figmaBlue)
                    .clipShape(Circle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
            .offset(x: 52, y: 90)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            floatCard = true
            pulse = true
        }
    }
}

private struct CommunityTourIllustration: View {
    @State private var glow = false
    @State private var wave = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.10))
                .frame(width: 230, height: 230)
                .scaleEffect(glow ? 1.03 : 0.92)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glow)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    avatar(symbol: "person.fill")
                    avatar(symbol: "person.fill")
                    avatar(symbol: "person.fill")
                }

                HStack(spacing: 8) {
                    Text("You’ve got this 💛")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.figmaBlue)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.figmaBlue)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
            }
            .offset(y: wave ? -6 : 6)
            .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: wave)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            glow = true
            wave = true
        }
    }

    private func avatar(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.figmaBlue)
            .frame(width: 38, height: 38)
            .background(.white)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
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
                step: .constant(.phoneNumber),
                onComplete: {},
                onSkip: {}
            )
            .previewDisplayName("Phone Number")
        }
    }
}
#endif
