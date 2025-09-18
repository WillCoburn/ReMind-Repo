

// =================================
// File: Services/MockDataStore.swift
// =================================
import Foundation


actor MockDataStore: DataStore {
private var user: UserProfile?
private var items: [Affirmation] = []


func createOrUpdateUser(_ profile: UserProfile) async throws {
user = profile
}


func currentUser() async throws -> UserProfile? { user }


func addAffirmation(_ text: String) async throws -> Affirmation {
let a = Affirmation(text: text)
items.insert(a, at: 0)
return a
}


func listAffirmations() async throws -> [Affirmation] { items }


func markDelivered(id: String) async throws {
if let idx = items.firstIndex(where: { $0.id == id }) {
items[idx].delivered = true
}
}
}
