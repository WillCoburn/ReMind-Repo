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
        XCTAssertEqual(StreakCalculator.compute(entries: [entry], calendar: calendar).count, 1)
    }

    func testMultipleEntriesSameDayDoNotDoubleCount() {
        let now = Date()
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let evening = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)!

        let entries = [
            Entry(id: "1", text: "", createdAt: morning, sent: false),
            Entry(id: "2", text: "", createdAt: evening, sent: false)
        ]

        XCTAssertEqual(StreakCalculator.compute(entries: entries, calendar: calendar).count, 1)
    }

    func testConsecutiveDaysAcrossMidnightCountTowardsStreak() {
        let todayStart = calendar.startOfDay(for: Date())
        let justAfterMidnight = calendar.date(byAdding: .minute, value: 1, to: todayStart)!
        let justBeforeMidnight = calendar.date(byAdding: .minute, value: -1, to: todayStart)!

        let entries = [
            Entry(id: "1", text: "", createdAt: justAfterMidnight, sent: false),
            Entry(id: "2", text: "", createdAt: justBeforeMidnight, sent: false)
        ]

        XCTAssertEqual(StreakCalculator.compute(entries: entries, calendar: calendar).count, 2)
    }

    func testMissingDayBreaksStreak() {
        let today = Date()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let entries = [
            Entry(id: "1", text: "", createdAt: today, sent: false),
            Entry(id: "2", text: "", createdAt: twoDaysAgo, sent: false)
        ]

        XCTAssertEqual(StreakCalculator.compute(entries: entries, calendar: calendar).count, 1)
    }

    func testLoadingSubscriptionDoesNotUnlockProControls() {
        let capabilities = SubscriptionCapabilities.resolve(
            state: .loading,
            lastKnownSubscribed: false
        )

        XCTAssertFalse(capabilities.isProUser)
        XCTAssertFalse(capabilities.canUseProReminderRange)
        XCTAssertTrue(capabilities.shouldApplyFreeUsageLimits)
        XCTAssertFalse(
            capabilities.shouldShowUpgradeMessaging
        )
        XCTAssertEqual(capabilities.maxRemindersPerWeek, SubscriptionLimits.freeMaxRemindersPerWeek)
    }

    func testLoadingKnownSubscribedAvoidsPaywallFlickerWithoutUnlockingControls() {
        let capabilities = SubscriptionCapabilities.resolve(
            state: .loading,
            lastKnownSubscribed: true
        )

        XCTAssertFalse(capabilities.isProUser)
        XCTAssertFalse(capabilities.canUseProReminderRange)
        XCTAssertTrue(capabilities.shouldApplyFreeUsageLimits)
        XCTAssertFalse(capabilities.shouldShowUpgradeMessaging)
        XCTAssertEqual(capabilities.maxRemindersPerWeek, SubscriptionLimits.freeMaxRemindersPerWeek)
    }

    func testFreeSubscriptionUsesFreeLimits() {
        let capabilities = SubscriptionCapabilities.resolve(
            state: .free,
            lastKnownSubscribed: false
        )

        XCTAssertFalse(capabilities.isProUser)
        XCTAssertTrue(capabilities.shouldShowUpgradeMessaging)
        XCTAssertTrue(capabilities.shouldApplyFreeUsageLimits)
        XCTAssertEqual(capabilities.maxRemindersPerWeek, SubscriptionLimits.freeMaxRemindersPerWeek)
    }

    func testSubscribedSubscriptionUsesProLimits() {
        let capabilities = SubscriptionCapabilities.resolve(
            state: .subscribed,
            lastKnownSubscribed: false
        )

        XCTAssertTrue(capabilities.isProUser)
        XCTAssertFalse(capabilities.shouldShowUpgradeMessaging)
        XCTAssertFalse(capabilities.shouldApplyFreeUsageLimits)
        XCTAssertEqual(capabilities.maxRemindersPerWeek, SubscriptionLimits.proMaxRemindersPerWeek)
    }

    func testProAutomatedReminderLimitIsFourteenPerWeek() {
        XCTAssertEqual(SubscriptionLimits.proMaxRemindersPerWeek, 14)

        let capabilities = SubscriptionCapabilities.resolve(
            state: .subscribed,
            lastKnownSubscribed: false
        )

        XCTAssertEqual(capabilities.maxRemindersPerWeek, 14)
    }

    func testRevenueCatErrorDoesNotUnlockProControls() {
        let capabilities = SubscriptionCapabilities.resolve(
            state: .error,
            lastKnownSubscribed: true
        )

        XCTAssertFalse(capabilities.isProUser)
        XCTAssertFalse(capabilities.canUseProReminderRange)
        XCTAssertTrue(capabilities.shouldApplyFreeUsageLimits)
        XCTAssertFalse(capabilities.shouldShowUpgradeMessaging)
        XCTAssertEqual(capabilities.maxRemindersPerWeek, SubscriptionLimits.freeMaxRemindersPerWeek)
    }

    func testExpiredSubscriptionUsesFreeLimits() {
        let capabilities = SubscriptionCapabilities.resolve(
            state: .expired,
            lastKnownSubscribed: true
        )

        XCTAssertFalse(capabilities.isProUser)
        XCTAssertTrue(capabilities.shouldShowUpgradeMessaging)
        XCTAssertTrue(capabilities.shouldApplyFreeUsageLimits)
        XCTAssertEqual(capabilities.maxRemindersPerWeek, SubscriptionLimits.freeMaxRemindersPerWeek)
    }

    func testCancelledServerPlanRemainsProUntilBackendExpiresIt() {
        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: .pro,
            subscriptionStatus: "cancelled",
            profileLoaded: true,
            lastKnownSubscribed: false
        )

        XCTAssertEqual(capabilities.state, .subscribed)
        XCTAssertTrue(capabilities.isProUser)
        XCTAssertEqual(capabilities.maxRemindersPerWeek, SubscriptionLimits.proMaxRemindersPerWeek)
    }

    func testExpiredRevenueCatMirrorOverridesLegacyProPlan() {
        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: .pro,
            subscriptionStatus: "cancelled",
            profileLoaded: true,
            lastKnownSubscribed: true,
            rcEntitlementActive: true,
            rcExpiresAt: Date(timeIntervalSince1970: 1_000),
            referenceDate: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(capabilities.state, .expired)
        XCTAssertFalse(capabilities.isProUser)
        XCTAssertEqual(capabilities.maxRemindersPerWeek, SubscriptionLimits.freeMaxRemindersPerWeek)
    }

    func testActiveRevenueCatMirrorUnlocksProEvenDuringWebhookPlanDelay() {
        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: .free,
            subscriptionStatus: nil,
            profileLoaded: true,
            lastKnownSubscribed: false,
            rcEntitlementActive: true,
            rcExpiresAt: Date(timeIntervalSince1970: 2_000),
            referenceDate: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(capabilities.state, .subscribed)
        XCTAssertTrue(capabilities.isProUser)
        XCTAssertEqual(capabilities.maxRemindersPerWeek, SubscriptionLimits.proMaxRemindersPerWeek)
    }

    func testServerProfileProDoesNotShowUpgradeMessaging() {
        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: .pro,
            subscriptionStatus: "subscribed",
            profileLoaded: true,
            lastKnownSubscribed: false
        )

        XCTAssertEqual(capabilities.state, .subscribed)
        XCTAssertTrue(capabilities.isProUser)
        XCTAssertFalse(capabilities.shouldShowUpgradeMessaging)
        XCTAssertFalse(capabilities.shouldApplyFreeUsageLimits)
    }

    func testWebhookRefreshDelayFallsBackToFreeCapabilities() {
        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: .free,
            subscriptionStatus: nil,
            profileLoaded: true,
            lastKnownSubscribed: false
        )

        XCTAssertEqual(capabilities.state, .free)
        XCTAssertFalse(capabilities.isProUser)
        XCTAssertTrue(capabilities.shouldApplyFreeUsageLimits)
    }

    func testOfflineStaleFreeProfileDoesNotUseLastKnownProAccess() {
        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: .free,
            subscriptionStatus: nil,
            profileLoaded: true,
            lastKnownSubscribed: true
        )

        XCTAssertEqual(capabilities.state, .free)
        XCTAssertFalse(capabilities.isProUser)
        XCTAssertTrue(capabilities.shouldApplyFreeUsageLimits)
        XCTAssertTrue(capabilities.shouldShowUpgradeMessaging)
    }

    func testColdLaunchBeforeProfileLoadIsSafeLoading() {
        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: nil,
            subscriptionStatus: nil,
            profileLoaded: false,
            lastKnownSubscribed: false
        )

        XCTAssertEqual(capabilities.state, .loading)
        XCTAssertFalse(capabilities.isProUser)
        XCTAssertTrue(capabilities.shouldApplyFreeUsageLimits)
    }

    func testAuthTransitionLoadingDoesNotCarryPreviousProAccess() {
        let capabilities = SubscriptionCapabilities.resolve(
            serverPlan: nil,
            subscriptionStatus: nil,
            profileLoaded: false,
            lastKnownSubscribed: true
        )

        XCTAssertEqual(capabilities.state, .loading)
        XCTAssertFalse(capabilities.isProUser)
        XCTAssertFalse(capabilities.canUseProReminderRange)
        XCTAssertFalse(capabilities.shouldShowUpgradeMessaging)
    }
}
