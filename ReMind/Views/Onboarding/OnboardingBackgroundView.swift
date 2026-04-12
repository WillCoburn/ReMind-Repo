import SwiftUI

struct OnboardingBackgroundView: View {
    @State private var animateBlobs = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.palettePewter.opacity(0.04),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.figmaBlue.opacity(0.14),
                            Color.paletteTurquoise.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 22,
                        endRadius: 260
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 56)
                .offset(x: 0, y: -112)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.paletteTurquoise.opacity(0.16),
                            Color.palettePewter.opacity(0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 240
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 58)
                .offset(x: animateBlobs ? -136 : -108, y: animateBlobs ? -230 : -196)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.figmaBlue.opacity(0.14),
                            Color.palettePewter.opacity(0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 260
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 64)
                .offset(x: animateBlobs ? 156 : 126, y: animateBlobs ? 292 : 250)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.pink.opacity(0.10),
                            Color.palettePewter.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 25,
                        endRadius: 210
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 56)
                .offset(x: animateBlobs ? 62 : 34, y: animateBlobs ? -62 : -38)

            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 460, height: 260)
                .blur(radius: 34)
                .offset(y: -100)

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 200,
                        endRadius: 560
                    )
                )
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animateBlobs)
        .onAppear {
            animateBlobs = true
        }
    }
}
