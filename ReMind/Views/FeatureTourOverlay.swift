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
            message: "Your future self appreciates it.",
            imageName: "OnboardMeditate",
            textAlignment: .leading
        ),
        .init(
            step: .export,
            title: "Remind is your new home for those moments of clarity that always seem to slip away.",
            message: "Save them here instead – they'll be stored as a text message to your future self.",
            imageName: "Onboard2",
            textAlignment: .leading
        ),
        .init(
            step: .sendNow,
            title: "Or if you have something the world needs to hear, the Community Page is the place to uplift others.",
            message: "",
            imageName: "OnboardCommunity",
            textAlignment: .leading
        )
    ]

    private var isOnLastPage: Bool { step == .sendNow }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.blue.opacity(0.05)
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
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                .tint(.figmaBlue)

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
    let imageName: String
    let textAlignment: HorizontalAlignment

    init(step: AppViewModel.FeatureTourStep,
         title: String,
         message: String,
         imageName: String,
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

    var body: some View {
        VStack(alignment: page.textAlignment, spacing: 20) {

            VStack(alignment: page.textAlignment, spacing: 12) {
                Text(page.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.leading)

                if !page.message.isEmpty {
                    Text(page.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity,
                   alignment: Alignment(horizontal: page.textAlignment, vertical: .center))

            Spacer()

            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 16)
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
        }
    }
}
#endif
