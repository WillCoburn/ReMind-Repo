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
        switch state {
        case .subscribed:
            return true
        case .loading:
            return true
        case .error:
            return lastKnownSubscribed
        case .free, .expired:
            return false
        }
    }

    public static func maxRemindersPerWeek(
        state: SubscriptionState,
        lastKnownSubscribed: Bool
    ) -> Double {
        allowsProRange(state: state, lastKnownSubscribed: lastKnownSubscribed)
            ? proMaxRemindersPerWeek
            : freeMaxRemindersPerWeek
    }

    public static func shouldShowUpgradeMessaging(
        state: SubscriptionState,
        lastKnownSubscribed: Bool
    ) -> Bool {
        switch state {
        case .free, .expired:
            return true
        case .error:
            return !lastKnownSubscribed
        case .loading, .subscribed:
            return false
        }
    }

    public static func shouldApplyFreeUsageLimits(
        state: SubscriptionState,
        lastKnownSubscribed: Bool
    ) -> Bool {
        shouldShowUpgradeMessaging(state: state, lastKnownSubscribed: lastKnownSubscribed)
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
        self.receivedCount = receivedCount
        self.usage = usage
        self.lastReminder = lastReminder
    }
}
