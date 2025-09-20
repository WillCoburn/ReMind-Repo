//
//  DataStore.swift
//  ReMind
//
//  Created by Will Coburn on 9/19/25.
//


// =======================
// File: Services/DataStore.swift
// =======================
import Foundation

public protocol DataStore: Sendable {
    // User
    func createOrUpdateUser(_ profile: UserProfile) async throws
    func currentUser() async throws -> UserProfile?

    // Affirmations
    func addAffirmation(_ text: String) async throws -> Affirmation
    func listAffirmations() async throws -> [Affirmation]
    func markDelivered(id: String) async throws
}
