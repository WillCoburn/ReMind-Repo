import SwiftUI

struct BottleAnimationView: View {
    let size: CGSize

    @State private var bottleBob = false
    @State private var bottleTilt = false
    @State private var noteDrift = false
    @State private var glintSweep = false

    init(width: CGFloat = 72, height: CGFloat = 122) {
        self.size = CGSize(width: width, height: height)
    }

    var body: some View {
        OceanBottleShape()
            .fill(Color(red: 196/255, green: 231/255, blue: 1).opacity(0.28))
            .frame(width: size.width, height: size.height)
            .overlay {
                OceanBottleShape()
                    .stroke(Color.figmaBlue.opacity(0.58), lineWidth: 1.8)
            }
            .overlay {
                BottleWaveLineShape()
                    .stroke(Color.figmaBlue.opacity(0.34), style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
                    .frame(width: size.width * 0.44, height: size.height * 0.06)
                    .offset(y: size.height * 0.18)
            }
            .overlay(alignment: .top) {
                VStack(spacing: 1.5) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(red: 173/255, green: 123/255, blue: 76/255))
                        .frame(width: size.width * 0.22, height: size.height * 0.08)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(Color(red: 120/255, green: 79/255, blue: 48/255).opacity(0.65), lineWidth: 0.9)
                        )
                    Capsule()
                        .fill(Color(red: 235/255, green: 244/255, blue: 1).opacity(0.9))
                        .frame(width: size.width * 0.20, height: 2.4)
                }
                .offset(y: size.height * 0.06)
            }
            .overlay(alignment: .bottom) {
                Ellipse()
                    .stroke(Color.white.opacity(0.42), lineWidth: 1.2)
                    .frame(width: size.width * 0.30, height: size.height * 0.05)
                    .offset(y: -size.height * 0.04)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(red: 250/255, green: 244/255, blue: 228/255).opacity(0.98))
                    .frame(width: size.width * 0.42, height: size.height * 0.14)
                    .rotationEffect(.degrees(-16))
                    .overlay {
                        VStack(alignment: .leading, spacing: 2) {
                            Capsule().fill(Color.figmaBlue.opacity(0.35)).frame(width: size.width * 0.18, height: 2)
                            Capsule().fill(Color.figmaBlue.opacity(0.26)).frame(width: size.width * 0.12, height: 2)
                        }
                        .offset(x: -size.width * 0.05, y: 1)
                    }
                    .offset(x: noteDrift ? -1.5 : 1.5, y: noteDrift ? size.height * 0.10 : size.height * 0.08)
                    .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.2), value: noteDrift)
            }
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.0), Color.white.opacity(0.35), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.width * 0.2, height: size.height * 1.12)
                    .rotationEffect(.degrees(14))
                    .offset(x: glintSweep ? size.width * 0.58 : -size.width * 0.58, y: -3)
                    .opacity(0.45)
                    .animation(.easeInOut(duration: 3.8).repeatForever(autoreverses: false), value: glintSweep)
                    .mask {
                        OceanBottleShape()
                    }
            }
            .rotationEffect(.degrees(45 + (bottleTilt ? 2.1 : -2.1)))
            .offset(y: bottleBob ? -3 : 3)
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
            .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: bottleTilt)
            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: bottleBob)
            .onAppear {
                bottleBob = true
                bottleTilt = true
                noteDrift = true
                glintSweep = true
            }
            .accessibilityHidden(true)
    }
}

private struct BottleWaveLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: midY),
            control: CGPoint(x: rect.midX, y: midY - rect.height * 0.6)
        )
        return path
    }
}

private struct OceanBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let neckWidth = rect.width * 0.14
        let neckX = rect.midX - neckWidth / 2
        let lipY = rect.height * 0.06
        let neckBottomY = rect.height * 0.30
        let shoulderY = rect.height * 0.40
        let widestY = rect.height * 0.74
        let baseY = rect.height * 0.95

        path.move(to: CGPoint(x: neckX, y: lipY))
        path.addLine(to: CGPoint(x: neckX, y: neckBottomY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.24, y: shoulderY),
            control: CGPoint(x: rect.width * 0.28, y: rect.height * 0.36)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.22, y: widestY),
            control: CGPoint(x: rect.width * 0.21, y: rect.height * 0.58)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.33, y: baseY),
            control: CGPoint(x: rect.width * 0.23, y: rect.height * 0.90)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.67, y: baseY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.78, y: widestY),
            control: CGPoint(x: rect.width * 0.77, y: rect.height * 0.90)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.76, y: shoulderY),
            control: CGPoint(x: rect.width * 0.79, y: rect.height * 0.58)
        )
        path.addQuadCurve(
            to: CGPoint(x: neckX + neckWidth, y: neckBottomY),
            control: CGPoint(x: rect.width * 0.72, y: rect.height * 0.36)
        )
        path.addLine(to: CGPoint(x: neckX + neckWidth, y: lipY))
        path.closeSubpath()
        return path
    }
}
