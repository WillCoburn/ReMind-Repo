// ============================
// File: Utils/StreakCalculator.swift
// ============================
import Foundation

enum StreakCalculator {
    static func compute(entries: [Entry], calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: Date())

        let uniqueDays = Set(
            entries.compactMap { entry -> Date? in
                guard let createdAt = entry.createdAt else { return nil }
                return calendar.startOfDay(for: createdAt)
            }
        ).sorted(by: >)

        guard let mostRecentDay = uniqueDays.first, mostRecentDay == today else { return 0 }

        var streak = 1
        var expectedDay = today

        for day in uniqueDays.dropFirst() {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: expectedDay) else { break }
            guard day == previous else { break }
            streak += 1
            expectedDay = previous
        }

        return streak
    }
}
