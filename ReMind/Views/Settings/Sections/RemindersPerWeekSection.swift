// ===========================================================
// File: Views/Settings/Sections/RemindersPerWeekSection.swift
// ===========================================================
import SwiftUI

struct RemindersPerWeekSection: View {
    @Binding var remindersPerWeek: Double

    private let minReminders: Double = 0
    private let maxReminders: Double = 20
    private let stepReminders: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Automated ReMinders Per Weekk")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(SettingsHelpers.remindersDisplay(remindersPerWeek)) / week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $remindersPerWeek,
                   in: minReminders...maxReminders,
                   step: stepReminders)
        }
    }
}
