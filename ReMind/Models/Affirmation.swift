// ============================
// File: Models/Affirmation.swift
// ============================
import Foundation

public struct Affirmation: Identifiable, Sendable, Equatable {
    public let id: String
    public var text: String
    public var createdAt: Date?
    public var sent: Bool

    public init(id: String, text: String, createdAt: Date? = nil, sent: Bool = false) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.sent = sent
    }
}
