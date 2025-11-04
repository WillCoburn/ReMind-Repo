// ================================
// File: Views/FeatureTourOverlay.swift
// ================================
import SwiftUI

struct FeatureTourOverlay: View {
    let step: AppViewModel.FeatureTourStep
    let onNext: () -> Void
    let onSkip: () -> Void

    private let totalSteps = AppViewModel.FeatureTourStep.allCases.count

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(alignment: .trailing, spacing: 28) {
                Spacer().frame(height: topSpacing)

                HStack {
                    Spacer()
                    FeatureTourCallout(
                        iconName: iconName,
                        title: calloutTitle,
                        message: calloutMessage
                    )
                    .frame(maxWidth: 320)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Spacer()

                FeatureTourControls(
                    stepText: "Step \(step.index) of \(totalSteps)",
                    nextTitle: nextTitle,
                    onNext: onNext,
                    onSkip: onSkip,
                    showSkip: step != .sendNow
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var calloutTitle: String {
        switch step {
        case .settings:
            return "Settings & personalization"
        case .export:
            return "Export your reflections"
        case .sendNow:
            return "Instant reminders"
        }
    }

    private var calloutMessage: String {
        switch step {
        case .settings:
            return "This is where SMS settings, customizable background, and subscription details can be found."
        case .export:
            return "This is where you can get a PDF of all entries after at least ten have been added."
        case .sendNow:
            return "This is where you can instantly get a ReMinder after a minimum of ten entries."
        }
    }

    private var iconName: String {
        switch step {
        case .settings: return "gearshape.fill"
        case .export:  return "envelope.fill"
        case .sendNow: return "bolt.fill"
        }
    }

    private var nextTitle: String {
        step == .sendNow ? "Got it" : "Next"
    }

    private var topSpacing: CGFloat {
        switch step {
        case .settings: return 110
        case .export:  return 170
        case .sendNow: return 210
        }
    }
}

// MARK: - Callout Card
private struct FeatureTourCallout: View {
    let iconName: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: iconName)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 6)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.black)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 12)
        )
    }
}

// MARK: - Bottom Controls
private struct FeatureTourControls: View {
    let stepText: String
    let nextTitle: String
    let onNext: () -> Void
    let onSkip: () -> Void
    let showSkip: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(stepText)
                .font(.footnote.weight(.medium))
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 12) {
                if showSkip {
                    Button(action: onSkip) {
                        Text("Skip tour")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            )
                    }
                }

                Spacer()

                Button(action: onNext) {
                    Text(nextTitle)
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 28)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
struct FeatureTourOverlay_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FeatureTourOverlay(
                step: .settings,
                onNext: {},
                onSkip: {}
            )
            .previewDisplayName("Settings")

            FeatureTourOverlay(
                step: .export,
                onNext: {},
                onSkip: {}
            )
            .previewDisplayName("Export")

            FeatureTourOverlay(
                step: .sendNow,
                onNext: {},
                onSkip: {}
            )
            .previewDisplayName("Send Now")
        }
    }
}
#endif
