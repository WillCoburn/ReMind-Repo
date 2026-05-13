import SwiftUI

struct RemindersPerWeekSection: View {
    @Binding var remindersPerWeek: Double
    let isProUser: Bool

    private let minReminders: Double = 1
    private let maxReminders: Double = 20
    private let freeMaxReminders: Double = 3
    private let stepReminders: Double = 1

    private var freeSliderBinding: Binding<Double> {
        Binding(
            get: { min(max(remindersPerWeek, minReminders), freeMaxReminders) },
            set: { remindersPerWeek = min(max($0, minReminders), freeMaxReminders) }
        )
    }

    private var selectedProgress: CGFloat {
        CGFloat((freeSliderBinding.wrappedValue - minReminders) / (maxReminders - minReminders))
    }

    private var freeRangeProgress: CGFloat {
        CGFloat((freeMaxReminders - minReminders) / (maxReminders - minReminders))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    remindersTitle
                    Spacer(minLength: 12)
                    remindersValue
                }

                VStack(alignment: .leading, spacing: 4) {
                    remindersTitle
                    remindersValue
                }
            }

            if isProUser {
                Slider(
                    value: $remindersPerWeek,
                    in: minReminders...maxReminders,
                    step: stepReminders
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Slider(
                        value: freeSliderBinding,
                        in: minReminders...freeMaxReminders,
                        step: stepReminders
                    )

                    GeometryReader { geo in
                        let width = geo.size.width
                        let selectedWidth = width * selectedProgress
                        let freeRangeWidth = width * freeRangeProgress
                        let lockedWidth = max(0, width - freeRangeWidth)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.gray.opacity(0.18))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.figmaBlue.opacity(0.22))
                                .frame(width: selectedWidth, height: 8)

                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.gray.opacity(0.30))
                                .frame(width: lockedWidth, height: 8)
                                .offset(x: freeRangeWidth)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("1")
                        Spacer()
                        Text("3")
                        Spacer()
                        Text("20")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack {
                        Text("Free")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.figmaBlue)

                        Spacer()

                        Text("Pro")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text("Upgrade to access 4-20 reminders/week")
                        .font(.caption)
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

    private var remindersTitle: some View {
        Text("Automated ReMinders Per Week")
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var remindersValue: some View {
        Text("\(SettingsHelpers.remindersDisplay(remindersPerWeek)) / week")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}
