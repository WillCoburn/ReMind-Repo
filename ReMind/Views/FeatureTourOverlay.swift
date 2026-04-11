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
            imageName: "OnboardMeditate",
            textAlignment: .center
        ),
        .init(
            step: .export,
            title: "Think of this app as a micro-journal for your flashes of clarity and positivity.",
            message: "These things that inspire you will be randomly texted back, hopefully to remind you when you need it most.",
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
            title: "Next, we’ll ask for your phone number.",
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

    private var illustration: some View {
        Group {
            switch page.step {
            case .settings:
                WelcomeTourIllustration()
            case .export:
                ExportTourIllustration()
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
    @State private var glow = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.12))
                .frame(width: 240, height: 240)
                .scaleEffect(glow ? 1.02 : 0.90)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
                .frame(width: 240, height: 150)
                .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(0.20), lineWidth: 1)
                )
                .offset(y: bob ? -6 : 6)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: bob)

            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.figmaBlue)

                Text("Welcome")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color.figmaBlue.opacity(0.25))
                            .frame(width: 34, height: 8)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(["heart.fill", "sun.max.fill"], id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.figmaBlue)
                        .padding(9)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                }
            }
            .offset(x: 92, y: -64)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            bob = true
            glow = true
        }
    }
}

private struct ExportTourIllustration: View {
    @State private var bob = false
    @State private var drift = false
    @State private var noteVisible = false
    @State private var reminderVisible = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.10))
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

            // Water line
            Capsule()
                .fill(Color.figmaBlue.opacity(0.14))
                .frame(width: 182, height: 8)
                .offset(y: 18)

            // Floating bottle
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white)
                    .frame(width: 88, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.figmaBlue.opacity(0.35), lineWidth: 1)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.figmaBlue.opacity(0.20))
                            .frame(width: 36, height: 5)
                            .offset(y: -12)
                    }

                VStack(spacing: 2) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.figmaBlue)
                    Text("tiny win")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.figmaBlue.opacity(0.85))
                }
            }
            .rotationEffect(.degrees(drift ? 6 : -6))
            .offset(x: drift ? 52 : -52, y: drift ? -8 : 8)
            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: drift)

            // Draft note (before it goes in bottle)
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                Text("A tiny win today")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.figmaBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            .offset(x: -34, y: -56)
            .opacity(noteVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: noteVisible)

            // Return reminder bubble (later)
            HStack(spacing: 6) {
                Image(systemName: "message.fill")
                Text("Sent back when needed")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.figmaBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            .offset(x: 24, y: 62)
            .opacity(reminderVisible ? 1 : 0.45)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: reminderVisible)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .onAppear {
            bob = true
            drift = true
            noteVisible = true
            reminderVisible = true
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
    @State private var bob = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.10))
                .frame(width: 230, height: 230)
                .scaleEffect(pulse ? 1.0 : 0.93)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
                .frame(width: 220, height: 170)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
                .offset(y: bob ? -5 : 5)
                .animation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true), value: bob)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "person.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.figmaBlue.opacity(0.85))
                            .clipShape(Circle())
                    }
                }

                Text("Community")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                    Text("Share positivity")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.figmaBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.figmaBlue.opacity(0.12))
                .clipShape(Capsule())
            }

            Image(systemName: "paperplane.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.figmaBlue)
                .padding(10)
                .background(.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                .offset(x: 96, y: -66)
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
