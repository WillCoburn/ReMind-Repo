// ============================
// File: Utils/StreakCalculator.swift
// ============================
import Foundation

struct StreakStatus {
    let count: Int
    let isInGracePeriod: Bool
}

enum StreakCalculator {
    static func compute(entries: [Entry], calendar: Calendar) -> StreakStatus {
        let timestamps = entries.compactMap { $0.createdAt }

        guard let lastEntryDate = timestamps.sorted(by: >).first else {
            return StreakStatus(count: 0, isInGracePeriod: false)
        }

        let hoursSinceLastEntry = max(0, Date().timeIntervalSince(lastEntryDate)) / 3600
        guard hoursSinceLastEntry < 24 else {
            return StreakStatus(count: 0, isInGracePeriod: false)
        }

        let uniqueDays = Set(timestamps.map { calendar.startOfDay(for: $0) })
        let lastEntryDay = calendar.startOfDay(for: lastEntryDate)

        var streak = 1
        var expectedDay = lastEntryDay

        while let previous = calendar.date(byAdding: .day, value: -1, to: expectedDay),
              uniqueDays.contains(previous) {
            streak += 1
            expectedDay = previous
        }

        let isInGracePeriod = !calendar.isDateInToday(lastEntryDate)

        return StreakStatus(count: streak, isInGracePeriod: isInGracePeriod)
    }
}
