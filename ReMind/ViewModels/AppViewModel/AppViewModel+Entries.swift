// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+Entries.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore


extension AppViewModel {
    // MARK: - Entries
    
    var sentEntriesCount: Int {
          entries.filter { $0.sent }.count
      }

    var streakCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let uniqueDays = Set(
            entries.compactMap { entry in
                guard let createdAt = entry.createdAt else { return nil }
                return calendar.startOfDay(for: createdAt)
            }
        ).sorted(by: >)

        guard let mostRecentDay = uniqueDays.first, mostRecentDay == today else { return 0 }

        var streak = 1

        for day in uniqueDays.dropFirst() {
            let dayDifference = calendar.dateComponents([.day], from: day, to: today).day ?? 0

            guard dayDifference == streak else { break }

            streak += 1
          }

          return streak
      }
    
      func attachEntriesListener(_ uid: String) {
          entriesListener?.remove()
          entriesListener = db.collection("users")
              .document(uid)
              .collection("entries")
              .order(by: "createdAt", descending: true)
              .addSnapshotListener { [weak self] snapshot, error in
                  guard let self = self else { return }
                  if let error {
                      print("❌ entries listener error:", error.localizedDescription)
                      return
                  }

                  guard let documents = snapshot?.documents else { return }
                  self.entries = documents.compactMap(self.mapEntry)
              }
      }

      func detachEntriesListener() {
          entriesListener?.remove()
          entriesListener = nil
      }
    
    func submit(text: String) async {
        print("🧪 submit tapped")

        guard NetworkMonitor.shared.isConnected else {
            print("❌ submit blocked: offline")
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ submit blocked: no auth uid")
            return
        }

        print("🧪 submit uid:", uid)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("❌ submit blocked: empty text")
            return
        }

        do {
            try await Task.detached(priority: .userInitiated) {
                let db = Firestore.firestore()
                let ref = db.collection("users")
                    .document(uid)
                    .collection("entries")
                    .document()

                print("🧪 submit writing to:", ref.path)

                try await ref.setData([
                    "text": trimmed,
                    "createdAt": FieldValue.serverTimestamp(),
                    "sent": false
                ])

                print("✅ submit write success")
            }.value
        } catch {
            print("❌ submit write failed:", error.localizedDescription)
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

            self.entries = snapshot.documents.compactMap(mapEntry)
            
        } catch {
            print("❌ refreshAll error:", error.localizedDescription)
        }
    }
    
    private func mapEntry(_ doc: QueryDocumentSnapshot) -> Entry? {
        let data = doc.data()
        guard let text = data["text"] as? String else { return nil }
        let ts = (data["createdAt"] as? Timestamp)?.dateValue()
        let sent = data["sent"] as? Bool ?? false

        return Entry(
            id: doc.documentID,
            text: text,
            createdAt: ts,
            sent: sent
        )
    }
}
