// ==========================
// File: Services/DataStore.swift
// ==========================
import Foundation


protocol DataStore {
func createOrUpdateUser(_ profile: UserProfile) async throws
func currentUser() async throws -> UserProfile?


func addAffirmation(_ text: String) async throws -> Affirmation
func listAffirmations() async throws -> [Affirmation]
func markDelivered(id: String) async throws
}
