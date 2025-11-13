// Views/Components/HintBadge.swift
import SwiftUI

struct HintBadge: View {
    let count: Int
    let goal: Int

    @State private var show: Bool                  // controls collapse
    @State private var flash: Bool = false         // single flash when reaching goal

    init(count: Int, goal: Int) {
        self.count = count
        self.goal = goal
        _show = State(initialValue: count < goal)
    }
    
    
    private var progress: Double {
        min(Double(count) / Double(goal), 1.0)
    }

    var body: some View {
        Group {
            if show {
                VStack(spacing: 8) {
                    // message
                    Text(count < goal
                         ? "Add \(goal - count) more to unlock reminders"
                         : "Nice! You’re ready 🎉")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                            RoundedRectangle(cornerRadius: 8)
                                .fill(flash ? Color.green : Color.accentColor)
                                .frame(width: geo.size.width * progress)
                                .animation(.easeOut(duration: 0.35), value: progress)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.gray.opacity(0.12))
                        )
                )
                .scaleEffect(flash ? 1.04 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: flash)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale),
                                        removal: .opacity.combined(with: .scale)))
                .onChange(of: count) { newValue in
                    // When the user *reaches* the goal, flash once and collapse.
                    if newValue >= goal && show {
                        Haptics.success()
                        flash = true
                        // Collapse after a short delay so the flash is visible.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                show = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                flash = false
                            }
                        }
                    }
                }
            }
        }
    }
}
