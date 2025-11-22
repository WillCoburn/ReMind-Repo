// ============================
// File: Models/UserProfile.swift
// ============================
import Foundation




public struct UserProfile: Codable, Sendable, Equatable {
    public let uid: String          // Firebase Auth UID
    public var phoneE164: String    // e.g. "+15551234567"
    public var createdAt: Date?     // First created timestamp
    public var updatedAt: Date?     // Last updated timestamp

    // 🔽 Added for payment/trial UX & backend gating
    public var trialEndsAt: Date?   // End of in-app 30-day free period
    public var active: Bool?        // Convenience flag for backend send gating
    public var receivedCount: Int   // Total ReMinds delivered (auto/manual/PDF)

    public init(
        uid: String,
        phoneE164: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        trialEndsAt: Date? = nil,
        active: Bool? = nil,
        receivedCount: Int = 0
    ) {
        self.uid = uid
        self.phoneE164 = phoneE164
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.trialEndsAt = trialEndsAt
        self.active = active
        self.receivedCount = receivedCount
    }
}
