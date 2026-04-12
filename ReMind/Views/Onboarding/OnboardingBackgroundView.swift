import SwiftUI

struct OnboardingBackgroundView: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 247/255, green: 250/255, blue: 1),
                    Color(red: 243/255, green: 247/255, blue: 1),
                    .white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.figmaBlue.opacity(0.11),
                            Color.figmaBlue.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 290
                    )
                )
                .frame(width: 540, height: 420)
                .blur(radius: 42)
                .offset(x: drift ? -32 : -8, y: drift ? -252 : -232)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.paletteTurquoise.opacity(0.12),
                            Color.paletteTurquoise.opacity(0.03),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 320
                    )
                )
                .frame(width: 560, height: 420)
                .blur(radius: 46)
                .offset(x: drift ? 42 : 18, y: drift ? 282 : 252)
        }
        .animation(.easeInOut(duration: 14).repeatForever(autoreverses: true), value: drift)
        .onAppear {
            drift = true
        }
    }
}
