

// ============================
// File: Models/Affirmation.swift
// ============================
import Foundation


struct Affirmation: Identifiable, Codable, Equatable {
let id: String
var text: String
var createdAt: Date
var delivered: Bool


init(id: String = UUID().uuidString, text: String, createdAt: Date = Date(), delivered: Bool = false) {
self.id = id
self.text = text
self.createdAt = createdAt
self.delivered = delivered
}
}
