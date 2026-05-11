// ============================
// File: Models/Affirmation.swift
// ============================
import Foundation

public struct Entry: Identifiable, Sendable, Equatable {
    public let id: String
    public var text: String
    public var createdAt: Date?
    public var sentAt: Date?
    public var sent: Bool

    public init(
        id: String,
        text: String,
        createdAt: Date? = nil,
        sentAt: Date? = nil,
        sent: Bool = false
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.sentAt = sentAt
        self.sent = sent
    }
}
