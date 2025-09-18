// ==================================
// File: App/CompositionRoot.swift
// ==================================

// App/CompositionRoot.swift
import Foundation

enum CompositionRoot {
    @MainActor
    static func makeAppViewModel() -> AppViewModel {
        let store: DataStore = MockDataStore()
        let messenger: MessagingService = MockMessagingService()
        let exporter: ExportService = MockExportService()
        return AppViewModel(store: store, messenger: messenger, exporter: exporter)
    }
}
