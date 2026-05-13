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
            ViewThatFits(in: .horizontal) {
                HStack {
                    sendWindowTitle
                    Spacer(minLength: 12)
                    sendWindowValue
                }

                VStack(alignment: .leading, spacing: 4) {
                    sendWindowTitle
                    sendWindowValue
                }
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

    private var sendWindowTitle: some View {
        Text("Automated Send Window")
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var sendWindowValue: some View {
        Text("\(hourLabel(startHour)) – \(hourLabel(endHour))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}
