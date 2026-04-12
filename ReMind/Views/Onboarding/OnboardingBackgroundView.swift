import SwiftUI

struct OnboardingBackgroundView: View {
    @State private var animateBlobs = false

    var body: some View {
        ZStack {
            Color(red: 248/255, green: 251/255, blue: 1)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            Color.figmaBlue.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 280
                    )
                )
                .frame(width: 440, height: 440)
                .blur(radius: 68)
                .offset(x: animateBlobs ? -18 : 8, y: animateBlobs ? -298 : -286)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.figmaBlue.opacity(0.13),
                            Color.cyan.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 36,
                        endRadius: 300
                    )
                )
                .frame(width: 480, height: 480)
                .blur(radius: 84)
                .offset(x: animateBlobs ? 176 : 146, y: animateBlobs ? 178 : 200)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.10),
                            Color.pink.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 28,
                        endRadius: 240
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 78)
                .offset(x: animateBlobs ? -162 : -124, y: animateBlobs ? 144 : 124)
        }
        .animation(.easeInOut(duration: 16).repeatForever(autoreverses: true), value: animateBlobs)
        .onAppear {
            animateBlobs = true
        }
    }
}
