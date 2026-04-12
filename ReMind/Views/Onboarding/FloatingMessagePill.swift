import SwiftUI

struct FloatingMessagePill: View {
    let text: String

    @State private var driftUp = false

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.figmaBlue)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.figmaBlue.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
            )
            .offset(y: driftUp ? -2 : 2)
            .animation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true), value: driftUp)
            .onAppear {
                driftUp = true
            }
            .accessibilityHidden(true)
    }
}
