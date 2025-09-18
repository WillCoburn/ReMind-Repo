// =============================
// File: Views/Components/HintBadge.swift
// =============================

import SwiftUI

/// Hint badge that:
///  - shows progress bar while `count < goal`
///  - when `count` reaches `goal`, flashes green, then collapses away
struct HintBadge: View {
    // Inputs
    let count: Int
    let goal: Int

    // Configurable messages
    var inProgressTitle: String {
        "Add \(max(0, goal - count)) more to start receiving texts."
    }
    var completionTitle: String = "You’re all set! We’ll start texting these back at random times."

    // Animation states
    @State private var isFlashing = false
    @State private var isCollapsed = false
    @State private var didCompleteOnce = false

    var body: some View {
        // Compute progress 0...1
        let progress = min(max(Double(count) / Double(max(goal, 1)), 0), 1)

        return Group {
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: count < goal ? "sparkles" : "checkmark.seal.fill")
                        Text(count < goal ? inProgressTitle : completionTitle)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .foregroundColor(count < goal ? .primary : .white)
                    }
                    .font(.footnote)

                    // Progress bar only while in progress
                    if count < goal {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(UIColor.tertiarySystemBackground))

                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: progress * geo.size.width)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            }
                        }
                        .frame(height: 6)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(backgroundFill)
                        .animation(.easeInOut(duration: 0.2), value: isFlashing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(borderStroke, lineWidth: 1)
                )
                // Collapse animation
                .opacity(isCollapsed ? 0 : 1)
                .frame(height: isCollapsed ? 0 : nil)
                .animation(.easeInOut(duration: 0.35), value: isCollapsed)
                // Listen for completion transition to trigger flash + collapse once
                .onChange(of: count) { newValue in
                    handleCountChange(newValue: newValue)
                }
                // If the view appears already completed (e.g., restoring state), still animate once
                .onAppear {
                    handleCountChange(newValue: count)
                }
            }
        }
    }

    // MARK: - Visual helpers
    private var backgroundFill: Color {
        if count >= goal {
            return isFlashing ? .green : .accentColor
        } else {
            return Color(UIColor.tertiarySystemBackground)
        }
    }

    private var borderStroke: Color {
        if count >= goal {
            return Color.green.opacity(0.35)
        } else {
            return Color.gray.opacity(0.2)
        }
    }

    // MARK: - Logic
    private func handleCountChange(newValue: Int) {
        guard newValue >= goal, !didCompleteOnce else { return }
        // Mark so we don’t replay on further changes
        didCompleteOnce = true

        // Flash to green, then collapse after a short delay
        withAnimation(.easeInOut(duration: 0.2)) { isFlashing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.2)) { isFlashing = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.35)) { isCollapsed = true }
            }
        }
    }
}
