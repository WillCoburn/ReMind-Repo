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

    private var streakStatus: StreakStatus {
        StreakCalculator.compute(entries: entries, calendar: streakCalendar)
    }

    var streakCount: Int {
        streakStatus.count
    }

    var isStreakInGracePeriod: Bool {
        streakStatus.isInGracePeriod
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
            Haptics.success()

            let optimistic = Entry(
                id: ref.documentID,
                text: trimmed,
                createdAt: Date(),
                sent: false
            )

            entries.removeAll { $0.id == optimistic.id }
            entries.insert(optimistic, at: 0)
        } catch {
            print("❌ submit write failed:", error.localizedDescription)
        }
    }

    func refreshLatestSentReminder() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            applyLatestSentReminder(nil)
            return
        }

        do {
            let userSnap = try await db.collection("users").document(uid).getDocument()
            let userReminder = parseLastReminder(from: userSnap.data() ?? [:])
            if var profile = user, profile.uid == uid {
                profile.lastReminder = userReminder
                user = profile
            }

            if let userReminder {
                applyLatestSentReminder(userReminder)
                return
            }

            let sentAtSnap = try await db.collection("users")
                .document(uid)
                .collection("entries")
                .order(by: "sentAt", descending: true)
                .limit(to: 1)
                .getDocuments()

            if let entry = sentAtSnap.documents.compactMap(mapEntry).first, entry.sent {
                applyLatestSentReminder(
                    LastReminder(
                        text: entry.text,
                        sentAt: entry.sentAt ?? entry.createdAt,
                        entryId: entry.id,
                        deliveredVia: nil
                    )
                )
            } else {
                applyLatestSentReminder(nil)
            }
        } catch {
            print("⚠️ refreshLatestSentReminder error:", error.localizedDescription)
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
        let sentAt = (data["sentAt"] as? Timestamp)?.dateValue()
        let sent = data["sent"] as? Bool ?? false

        return Entry(
            id: doc.documentID,
            text: text,
            createdAt: ts,
            sentAt: sentAt,
            sent: sent
        )
    }

    private var streakCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "tzIdentifier"), let tz = TimeZone(identifier: id) {
            calendar.timeZone = tz
        }
        return calendar
    }
}
