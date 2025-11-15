// ===================================================
// File: Views/Settings/Sections/SendWindowSection.swift
// ===================================================
import SwiftUI

struct SendWindowSection: View {
    @Binding var startHour: Double
    @Binding var endHour: Double

    var hourLabel: (Double) -> String

    private var binding: Binding<ClosedRange<Double>> {
        Binding(
            get: { startHour ... endHour },
            set: { r in
                startHour = max(0, min(23, r.lowerBound))
                endHour   = max(0, min(23, r.upperBound))
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Send Window")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(hourLabel(startHour)) – \(hourLabel(endHour))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                RangeSlider(
                    value: binding,
                    in: 0.0...23.0,
                    step: 1.0,
                    minimumValueLabel: {
                        Text(hourLabel(0.0))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    },
                    maximumValueLabel: {
                        Text(hourLabel(23.0))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                )

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(hourLabel(startHour)).font(.footnote.monospaced())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("End")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(hourLabel(endHour)).font(.footnote.monospaced())
                    }
                }
            }

            Text("Reminders will be scheduled only between these hours.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
