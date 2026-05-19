// ============================
// File: Models/UserProfile.swift
// ============================
import Foundation


public enum UserPlan: String, Codable, Sendable {
    case free
    case pro
}

public enum SubscriptionState: String, Codable, Sendable, Equatable {
    case loading
    case free
    case subscribed
    case expired
    case error

    public var isResolved: Bool {
        self != .loading
    }

    public var isSubscribed: Bool {
        self == .subscribed
    }
}

public enum SubscriptionLimits {
    public static let minRemindersPerWeek: Double = 1
    public static let freeMaxRemindersPerWeek: Double = 3
    public static let proMaxRemindersPerWeek: Double = 20

    public static func allowsProRange(
        state: SubscriptionState,
        lastKnownSubscribed: Bool
    ) -> Bool {
        SubscriptionCapabilities.resolve(
            state: state,
            lastKnownSubscribed: lastKnownSubscribed
        ).canUseProReminderRange
    }

    public static func maxRemindersPerWeek(
        state: SubscriptionState,
        lastKnownSubscribed: Bool
    ) -> Double {
        SubscriptionCapabilities.resolve(
            state: state,
            lastKnownSubscribed: lastKnownSubscribed
        ).maxRemindersPerWeek
    }

    public static func shouldShowUpgradeMessaging(
        state: SubscriptionState,
        lastKnownSubscribed: Bool
    ) -> Bool {
        SubscriptionCapabilities.resolve(
            state: state,
            lastKnownSubscribed: lastKnownSubscribed
        ).shouldShowUpgradeMessaging
    }

    public static func shouldApplyFreeUsageLimits(
        state: SubscriptionState,
        lastKnownSubscribed: Bool
    ) -> Bool {
        SubscriptionCapabilities.resolve(
            state: state,
            lastKnownSubscribed: lastKnownSubscribed
        ).shouldApplyFreeUsageLimits
    }
}

public struct SubscriptionCapabilities: Codable, Sendable, Equatable {
    public let state: SubscriptionState
    public let effectivePlan: UserPlan
    public let canUseProReminderRange: Bool
    public let maxRemindersPerWeek: Double
    public let shouldShowUpgradeMessaging: Bool
    public let shouldApplyFreeUsageLimits: Bool

    public var isProUser: Bool {
        effectivePlan == .pro
    }

    public static func resolve(
        state: SubscriptionState,
        lastKnownSubscribed: Bool
    ) -> SubscriptionCapabilities {
        let proUnlocked = state == .subscribed
        let showUpgrade: Bool
        switch state {
        case .free, .expired:
            showUpgrade = true
        case .error:
            showUpgrade = !lastKnownSubscribed
        case .loading, .subscribed:
            showUpgrade = false
        }

        return SubscriptionCapabilities(
            state: state,
            effectivePlan: proUnlocked ? .pro : .free,
            canUseProReminderRange: proUnlocked,
            maxRemindersPerWeek: proUnlocked
                ? SubscriptionLimits.proMaxRemindersPerWeek
                : SubscriptionLimits.freeMaxRemindersPerWeek,
            shouldShowUpgradeMessaging: showUpgrade,
            shouldApplyFreeUsageLimits: !proUnlocked
        )
    }

    public static func resolve(
        serverPlan: UserPlan?,
        subscriptionStatus: String?,
        profileLoaded: Bool,
        lastKnownSubscribed: Bool,
        rcEntitlementActive: Bool? = nil,
        rcExpiresAt: Date? = nil,
        referenceDate: Date = Date()
    ) -> SubscriptionCapabilities {
        guard profileLoaded else {
            return resolve(state: .loading, lastKnownSubscribed: lastKnownSubscribed)
        }

        let normalizedStatus = subscriptionStatus?.lowercased()
        let state: SubscriptionState
        if let rcExpiresAt, rcExpiresAt < referenceDate {
            state = .expired
        } else if rcEntitlementActive == true {
            state = .subscribed
        } else if serverPlan == .pro && rcEntitlementActive == nil && rcExpiresAt == nil {
            state = .subscribed
        } else if normalizedStatus == "expired" {
            state = .expired
        } else {
            state = .free
        }

        return resolve(state: state, lastKnownSubscribed: lastKnownSubscribed)
    }
}

public struct InstantUsage: Codable, Sendable, Equatable {
    public var instantWeekKey: String?
    public var instantSendsThisWeek: Int

    public init(instantWeekKey: String? = nil, instantSendsThisWeek: Int = 0) {
        self.instantWeekKey = instantWeekKey
        self.instantSendsThisWeek = instantSendsThisWeek
    }
}

public struct LastReminder: Codable, Sendable, Equatable {
    public var text: String
    public var sentAt: Date?
    public var entryId: String?
    public var deliveredVia: String?

    public init(
        text: String,
        sentAt: Date? = nil,
        entryId: String? = nil,
        deliveredVia: String? = nil
    ) {
        self.text = text
        self.sentAt = sentAt
        self.entryId = entryId
        self.deliveredVia = deliveredVia
    }
}



public struct UserProfile: Codable, Sendable, Equatable {
    public let uid: String          // Firebase Auth UID
    public var phoneE164: String    // e.g. "+15551234567"
    public var createdAt: Date?     // First created timestamp
    public var updatedAt: Date?     // Last updated timestamp

    // Legacy trial fields are intentionally retained for mixed-version compatibility.
    // CLEANUP AFTER: remove trial fields once all clients/backend paths are fully plan-based.
    public var trialEndsAt: Date?   // End of in-app 30-day free period
    public var active: Bool?        // Operational scheduler flag (STOP/START + send safety)
    public var plan: UserPlan?
    public var subscriptionStatus: String?
    public var rcEntitlementActive: Bool?
    public var rcExpiresAt: Date?
    public var receivedCount: Int?  // Total ReMinds delivered (auto/manual/PDF)
    public var usage: InstantUsage?
    public var lastReminder: LastReminder?

    public init(
        uid: String,
        phoneE164: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        trialEndsAt: Date? = nil,
        active: Bool? = nil,
        plan: UserPlan? = nil,
        subscriptionStatus: String? = nil,
        rcEntitlementActive: Bool? = nil,
        rcExpiresAt: Date? = nil,
        receivedCount: Int? = nil,
        usage: InstantUsage? = nil,
        lastReminder: LastReminder? = nil
    ) {
        self.uid = uid
        self.phoneE164 = phoneE164
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.trialEndsAt = trialEndsAt
        self.active = active
        self.plan = plan
        self.subscriptionStatus = subscriptionStatus
        self.rcEntitlementActive = rcEntitlementActive
        self.rcExpiresAt = rcExpiresAt
        self.receivedCount = receivedCount
        self.usage = usage
        self.lastReminder = lastReminder
    }
}
