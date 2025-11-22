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
                startHour = max(0, min(24, r.lowerBound))
                endHour   = max(0, min(24, r.upperBound))
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Automated Send Window")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(hourLabel(startHour)) – \(hourLabel(endHour))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                RangeSlider(
                    value: binding,
                    in: 0.0...24.0,
                    step: 1.0,
                )

            }

        }
    }
}
