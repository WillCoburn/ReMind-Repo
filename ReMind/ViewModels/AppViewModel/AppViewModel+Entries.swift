// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+Entries.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
extension AppViewModel {
    // MARK: - Entries
    func submit(text: String, isOnline: Bool = NetworkMonitor.shared.isConnected) async {
        guard isOnline else {
            print("⏸️ submit skipped: offline")
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try await db.collection("users")
                .document(uid)
                .collection("entries")
                .addDocument(data: [
                    "text": trimmed,
                    "createdAt": FieldValue.serverTimestamp(),
                    "sent": false
                ])
            await refreshAll()
        } catch {
            print("❌ submit error:", error.localizedDescription)
        }
    }

    func refreshAll() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("users")
                .document(uid)
                .collection("entries")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            self.entries = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let text = data["text"] as? String else { return nil }
                let ts = (data["createdAt"] as? Timestamp)?.dateValue()
                return Entry(id: doc.documentID, text: text, createdAt: ts)
            }
        } catch {
            print("❌ refreshAll error:", error.localizedDescription)
        }
    }
}
