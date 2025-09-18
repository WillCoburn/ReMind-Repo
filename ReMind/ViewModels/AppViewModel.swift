

// =============================
// File: ViewModels/AppViewModel.swift
// =============================
import Foundation
import SwiftUI


@MainActor
final class AppViewModel: ObservableObject {
    private let store: DataStore
    private let messenger: MessagingService
    private let exporter: ExportService
    
    
    @Published var isOnboarded: Bool = false
    @Published var profile: UserProfile?
    @Published var affirmations: [Affirmation] = []
    @Published var isExporting: Bool = false
    @Published var showExportResult: Bool = false
    
    
    init(store: DataStore, messenger: MessagingService, exporter: ExportService) {
        self.store = store
        self.messenger = messenger
        self.exporter = exporter
        Task { await load() }
    }
    
    
    func load() async {
        do {
            if let user = try await store.currentUser() {
                profile = user
                isOnboarded = true
                affirmations = try await store.listAffirmations()
            }
        } catch { print("Load error: \(error)") }
    }
    
    
    func onboard(phone: String) async {
        guard !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let p = UserProfile(phoneNumber: phone)
            try await store.createOrUpdateUser(p)
            profile = p
            isOnboarded = true
        } catch { print("Onboard error: \(error)") }
    }
    
    
    func submit(text: String) async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        do {
            let a = try await store.addAffirmation(t)
            affirmations.insert(a, at: 0)
            try await messenger.scheduleForFutureDelivery(a)
        } catch { print("Submit error: \(error)") }
    }
}
