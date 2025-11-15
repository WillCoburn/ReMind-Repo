import SwiftUI

// MARK: - Option 1: Soft Diagonal Gradient
// Simple, elegant gradient that won’t fight your text.
struct ReMindBackgroundSoftDiagonal: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#2A62FF"),
                Color(hex: "#28D7FF"),
                Color(hex: "#02D1C2")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Option 2: Radial Glow + Watermark
// Adds a faint center glow and a large low-opacity watermark of your logo.
struct ReMindBackgroundRadialWatermark: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#0A1222"),            // deep base
                    Color(hex: "#2A62FF").opacity(0.75),
                    Color(hex: "#02D1C2").opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // subtle center glow
            RadialGradient(
                colors: [
                    Color.white.opacity(0.16),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 380
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            // oversized watermark logo
            Image("AppMark")
                .resizable()
                .scaledToFit()
                .frame(width: 520)
                .opacity(0.06)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Option 3: Bracket Motif Pattern (very subtle)
// A soft, repeated “[…]” pattern in the background for brand texture.
struct ReMindBackgroundBracketPattern: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#2A62FF"),
                    Color(hex: "#02D1C2")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // repeating […] pattern
            GeometryReader { geo in
                let size: CGFloat = 120
                Canvas { ctx, _ in
                    let rows = Int(geo.size.height / size) + 2
                    let cols = Int(geo.size.width / size) + 2
                    let text = Text("[ ]")
                        .font(.system(size: 48, weight: .semibold, design: .rounded))

                    for r in 0..<rows {
                        for c in 0..<cols {
                            var resolved = ctx.resolve(text)
                            ctx.opacity = 0.06
                            ctx.translateBy(x: CGFloat(c) * size, y: CGFloat(r) * size)
                            resolved.shading = .color(.white)
                            ctx.draw(resolved, at: .zero, anchor: .topLeading)
                            ctx.translateBy(x: -CGFloat(c) * size, y: -CGFloat(r) * size)
                        }
                    }
                }
                .blendMode(.screen)
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Option 4: Dynamic Mist (very light motion, minimal)
// A subtle animated gradient shift (safe for most users; keep motion low).
struct ReMindBackgroundDynamicMist: View {
    @State private var t: CGFloat = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 4.0, paused: false)) { _ in
            ZStack {
                // two slowly shifting gradients
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#2A62FF"),
                        Color(hex: "#28D7FF"),
                        Color(hex: "#02D1C2"),
                        Color(hex: "#2A62FF")
                    ]),
                    center: .center,
                    angle: .degrees(Double(t) * 8.0)
                )
                .opacity(0.65)
                .blendMode(.plusLighter)

                LinearGradient(
                    colors: [
                        Color(hex: "#0A1222"),
                        Color(hex: "#2A62FF").opacity(0.6),
                        Color(hex: "#02D1C2").opacity(0.6)
                    ],
                    startPoint: UnitPoint(x: 0.3 + 0.05 * t, y: 0.0),
                    endPoint: UnitPoint(x: 1.0, y: 1.0)
                )
                .opacity(0.85)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                    t = 1.0
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Color(hex:) helper
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17,
                                (int >> 4 & 0xF) * 17,
                                (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16,
                                int >> 8 & 0xFF,
                                int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24,
                                int >> 16 & 0xFF,
                                int >> 8 & 0xFF,
                                int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
