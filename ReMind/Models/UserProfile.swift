// ==========================
// File: Models/UserProfile.swift
// ==========================
import Foundation


struct UserProfile: Codable, Equatable {
var phoneNumber: String
var createdAt: Date = Date()
}
