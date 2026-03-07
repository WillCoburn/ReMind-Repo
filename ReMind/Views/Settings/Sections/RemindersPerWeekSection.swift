// ===========================================================
// File: Views/Settings/Sections/RemindersPerWeekSection.swift
// ===========================================================
import SwiftUI

struct RemindersPerWeekSection: View {
    @Binding var remindersPerWeek: Double
    let isProUser: Bool

    private let minReminders: Double = 1
    private let maxReminders: Double = 20
    private let freeMaxReminders: Double = 3
    private let stepReminders: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Automated ReMinders Per Week")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(SettingsHelpers.remindersDisplay(remindersPerWeek)) / week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if isProUser {
                Slider(value: $remindersPerWeek,
                       in: minReminders...maxReminders,
                       step: stepReminders)
            } else {
                // Free control: only allow 1...3 interaction.
                Slider(
                    value: Binding(
                        get: { min(max(remindersPerWeek, minReminders), freeMaxReminders) },
                        set: { remindersPerWeek = min(max($0, minReminders), freeMaxReminders) }
                    ),
                    in: minReminders...freeMaxReminders,
                    step: stepReminders
                )

                // Visual continuation for Pro range 4...20.
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.figmaBlue.opacity(0.20))
                        .frame(height: 8)
                        .frame(maxWidth: .infinity)

                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.22))
                        .frame(height: 8)
                        .frame(maxWidth: .infinity)

                    Text("Pro")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            guard !isProUser else { return }
            if remindersPerWeek > freeMaxReminders || remindersPerWeek < minReminders {
                remindersPerWeek = min(max(remindersPerWeek, minReminders), freeMaxReminders)
            }
        }
    }
}
