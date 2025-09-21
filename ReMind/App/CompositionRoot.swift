// ====================
// File: App/CompositionRoot.swift
// ====================
import Foundation

enum CompositionRoot {
    @MainActor
    static func makeAppViewModel() -> AppViewModel {
        // AppViewModel now wires up its own Firebase services internally.
        return AppViewModel()
    }
}
