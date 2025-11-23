// ================================================
// File: Views/Settings/Components/RangeSlider.swift
// ================================================
import SwiftUI

struct RangeSlider<MinimumLabel: View, MaximumLabel: View>: View {
    @Binding var value: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    var step: Double
    @ViewBuilder var minimumValueLabel: () -> MinimumLabel
    @ViewBuilder var maximumValueLabel: () -> MaximumLabel

    private let handleDiameter: CGFloat = 28
    private let trackHeight: CGFloat = 4

    init(
        value: Binding<ClosedRange<Double>>,
        in bounds: ClosedRange<Double>,
        step: Double = 1,
        @ViewBuilder minimumValueLabel: @escaping () -> MinimumLabel,
        @ViewBuilder maximumValueLabel: @escaping () -> MaximumLabel
    ) {
        _value = value
        self.bounds = bounds
        self.step = step
        self.minimumValueLabel = minimumValueLabel
        self.maximumValueLabel = maximumValueLabel
    }

    private var totalSpan: Double { max(bounds.upperBound - bounds.lowerBound, .leastNonzeroMagnitude) }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let usableWidth = max(totalWidth - handleDiameter, 1)
                let lowerPosition = position(for: value.lowerBound, totalWidth: totalWidth)
                let upperPosition = position(for: value.upperBound, totalWidth: totalWidth)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: usableWidth, height: trackHeight)
                        .position(x: totalWidth / 2, y: handleDiameter / 2)

                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Color.accentColor)
                        .frame(width: max(upperPosition - lowerPosition, 0), height: trackHeight)
                        .position(x: lowerPosition + max((upperPosition - lowerPosition) / 2, 0),
                                  y: handleDiameter / 2)

                    sliderHandle
                        .position(x: lowerPosition, y: handleDiameter / 2)
                        .highPriorityGesture(dragGesture(forLowerHandleIn: totalWidth))

                    sliderHandle
                        .position(x: upperPosition, y: handleDiameter / 2)
                        .highPriorityGesture(dragGesture(forUpperHandleIn: totalWidth))
                }
                .frame(height: handleDiameter)
            }
            .frame(height: handleDiameter)

            HStack {
                minimumValueLabel()
                Spacer()
                maximumValueLabel()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Range")
        .accessibilityValue("\(Int(value.lowerBound)) to \(Int(value.upperBound))")
    }

    private var sliderHandle: some View {
        Circle()
            .fill(Color(uiColor: .white))
            .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            .shadow(radius: 1, y: 1)
            .frame(width: handleDiameter, height: handleDiameter)
    }

    private func percent(for rawValue: Double) -> CGFloat {
        let clamped = min(max(rawValue, bounds.lowerBound), bounds.upperBound)
        return CGFloat((clamped - bounds.lowerBound) / totalSpan)
    }

    private func position(for value: Double, totalWidth: CGFloat) -> CGFloat {
        let usableWidth = max(totalWidth - handleDiameter, 1)
        return percent(for: value) * usableWidth + handleDiameter / 2
    }

    private func dragGesture(forLowerHandleIn totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let newValue = value(for: gesture.location.x, totalWidth: totalWidth)
                let limited = min(newValue, value.upperBound)
                value = snapRange(limited...value.upperBound)
            }
    }

    private func dragGesture(forUpperHandleIn totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let newValue = value(for: gesture.location.x, totalWidth: totalWidth)
                let limited = max(newValue, value.lowerBound)
                value = snapRange(value.lowerBound...limited)
            }
    }

    private func value(for location: CGFloat, totalWidth: CGFloat) -> Double {
        let usableWidth = max(totalWidth - handleDiameter, 1)
        let clampedLocation = min(max(location, handleDiameter / 2), totalWidth - handleDiameter / 2)
        let percent = Double((clampedLocation - handleDiameter / 2) / usableWidth)
        let rawValue = bounds.lowerBound + percent * totalSpan
        return min(max(rawValue, bounds.lowerBound), bounds.upperBound)
    }

    private func snapRange(_ r: ClosedRange<Double>) -> ClosedRange<Double> {
        guard step > 0 else { return r }
        func snap(_ x: Double) -> Double {
            let rel = (x - bounds.lowerBound) / step
            return bounds.lowerBound + rel.rounded() * step
        }
        return snap(r.lowerBound) ... snap(r.upperBound)
    }
}

extension RangeSlider where MinimumLabel == EmptyView, MaximumLabel == EmptyView {
    init(value: Binding<ClosedRange<Double>>, in bounds: ClosedRange<Double>, step: Double = 1) {
        self.init(
            value: value,
            in: bounds,
            step: step,
            minimumValueLabel: { EmptyView() },
            maximumValueLabel: { EmptyView() }
        )
    }
}
