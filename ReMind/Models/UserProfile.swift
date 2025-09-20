// ============================
// File: Models/UserProfile.swift
// ============================
import Foundation

public struct UserProfile: Codable, Sendable, Equatable {
    public let uid: String          // Firebase Auth UID
    public var phoneE164: String    // e.g. "+15551234567"
    public var createdAt: Date?     // First created timestamp
    public var updatedAt: Date?     // Last updated timestamp

    public init(
        uid: String,
        phoneE164: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.uid = uid
        self.phoneE164 = phoneE164
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
