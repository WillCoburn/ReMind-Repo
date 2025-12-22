//
//  ReMindTests.swift
//  ReMindTests
//
//  Created by Will Coburn on 9/15/25.
//

import XCTest
@testable import ReMind

final class ReMindTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    func testFirstEntrySetsStreakToOne() {
        let entry = Entry(id: "1", text: "", createdAt: Date(), sent: false)
        XCTAssertEqual(StreakCalculator.compute(entries: [entry], calendar: calendar), 1)
    }

    func testMultipleEntriesSameDayDoNotDoubleCount() {
        let now = Date()
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let evening = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)!

        let entries = [
            Entry(id: "1", text: "", createdAt: morning, sent: false),
            Entry(id: "2", text: "", createdAt: evening, sent: false)
        ]

        XCTAssertEqual(StreakCalculator.compute(entries: entries, calendar: calendar), 1)
    }

    func testConsecutiveDaysAcrossMidnightCountTowardsStreak() {
        let todayStart = calendar.startOfDay(for: Date())
        let justAfterMidnight = calendar.date(byAdding: .minute, value: 1, to: todayStart)!
        let justBeforeMidnight = calendar.date(byAdding: .minute, value: -1, to: todayStart)!

        let entries = [
            Entry(id: "1", text: "", createdAt: justAfterMidnight, sent: false),
            Entry(id: "2", text: "", createdAt: justBeforeMidnight, sent: false)
        ]

        XCTAssertEqual(StreakCalculator.compute(entries: entries, calendar: calendar), 2)
    }

    func testMissingDayBreaksStreak() {
        let today = Date()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let entries = [
            Entry(id: "1", text: "", createdAt: today, sent: false),
            Entry(id: "2", text: "", createdAt: twoDaysAgo, sent: false)
        ]

        XCTAssertEqual(StreakCalculator.compute(entries: entries, calendar: calendar), 1)
    }
}
