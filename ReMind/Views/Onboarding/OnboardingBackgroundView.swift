import SwiftUI

struct OnboardingBackgroundView: View {
    @State private var animateBlobs = false

    var body: some View {
        ZStack {
            Color.white

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.paletteTurquoise.opacity(0.22),
                            Color.palettePewter.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 240
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 54)
                .offset(x: animateBlobs ? -122 : -92, y: animateBlobs ? -186 : -156)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.figmaBlue.opacity(0.18),
                            Color.palettePewter.opacity(0.13),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 260
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: animateBlobs ? 132 : 102, y: animateBlobs ? 272 : 242)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.pink.opacity(0.14),
                            Color.palettePewter.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 25,
                        endRadius: 210
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 52)
                .offset(x: animateBlobs ? 54 : 20, y: animateBlobs ? -54 : -32)
        }
        .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animateBlobs)
        .onAppear {
            animateBlobs = true
        }
    }
}
