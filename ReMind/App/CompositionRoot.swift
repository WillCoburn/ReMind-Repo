// =====================
// File: App/CompositionRoot.swift
// =====================
import Foundation

enum CompositionRoot {
    @MainActor
    static func makeAppViewModel() -> AppViewModel {
        // Use the real Firestore store
        let store: DataStore = FirestoreDataStore()
        return AppViewModel(store: store)
    }
}
