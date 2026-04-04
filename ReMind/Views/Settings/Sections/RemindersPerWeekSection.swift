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

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { remindersPerWeek },
            set: { newValue in
                let cappedValue = min(max(newValue, minReminders), maxReminders)
                remindersPerWeek = isProUser ? cappedValue : min(cappedValue, freeMaxReminders)
            }
        )
    }

    private var freeTrackWidthRatio: CGFloat {
        CGFloat((freeMaxReminders - minReminders) / (maxReminders - minReminders))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Automated ReMinders Per Week")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(SettingsHelpers.remindersDisplay(remindersPerWeek)) / week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !isProUser {
                Text("Free plan: up to 3 reminders/week. Upgrade for up to 20/week.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: sliderBinding,
                in: minReminders...maxReminders,
                step: stepReminders
            )

            if !isProUser {
                GeometryReader { geo in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.figmaBlue.opacity(0.25))
                            .frame(width: max((geo.size.width * freeTrackWidthRatio) - 6, 0), height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.22))
                            .frame(height: 8)
                    }
                }
                .frame(height: 8)
            }

            HStack {
                Text("1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("3 Free max")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isProUser ? .secondary : .figmaBlue)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("20 Pro")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            let lowerBounded = max(remindersPerWeek, minReminders)
            remindersPerWeek = isProUser ? min(lowerBounded, maxReminders) : min(lowerBounded, freeMaxReminders)
        }
        .onChange(of: isProUser) { pro in
            guard !pro else { return }
            remindersPerWeek = min(remindersPerWeek, freeMaxReminders)
        }
    }
}
