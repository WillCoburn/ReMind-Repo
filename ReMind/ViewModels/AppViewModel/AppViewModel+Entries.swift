// ============================
// File: App/ViewModels/AppViewModel/AppViewModel+Entries.swift
// ============================
import Foundation
import FirebaseAuth
import FirebaseFirestore


extension AppViewModel {
    // MARK: - Entries

    var activeEntries: [Entry] {
        entries.filter { !$0.deleted }
    }

    var sentEntriesCount: Int {
        activeEntries.filter { $0.sent }.count
    }

    private var streakStatus: StreakStatus {
        StreakCalculator.compute(entries: activeEntries, calendar: streakCalendar)
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
    
    @discardableResult
    func submit(text: String) async throws -> Entry {
        print("🧪 submit tapped")

        guard NetworkMonitor.shared.isConnected else {
            print("❌ submit blocked: offline")
            throw NSError(
                domain: "ReMindEntries",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "Please reconnect to the internet to save this reminder."]
            )
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ submit blocked: no auth uid")
            throw NSError(
                domain: "ReMindEntries",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Sign in required."]
            )
        }

        print("🧪 submit uid:", uid)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("❌ submit blocked: empty text")
            throw NSError(
                domain: "ReMindEntries",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Reminder text cannot be empty."]
            )
        }

        let entry = try await addEntryToBank(text: trimmed)
        print("✅ submit write success")
        Haptics.success()
        return entry
    }

    @discardableResult
    func addEntryToBank(
        text: String,
        source: String? = nil,
        sourceCategory: String? = nil
    ) async throws -> Entry {
        guard NetworkMonitor.shared.isConnected else {
            throw NSError(
                domain: "ReMindEntries",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "Please reconnect to the internet to save this reminder."]
            )
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(
                domain: "ReMindEntries",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Sign in required."]
            )
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(
                domain: "ReMindEntries",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Reminder text cannot be empty."]
            )
        }

        if let duplicate = activeEntries.first(where: { normalizedEntryText($0.text) == normalizedEntryText(trimmed) }) {
            return duplicate
        }

        let ref = db.collection("users")
            .document(uid)
            .collection("entries")
            .document()

        print("🧪 entry writing to:", ref.path)

        var data: [String: Any] = [
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp(),
            "sent": false,
            "deleted": false
        ]

        if let source {
            data["source"] = source
        }

        if let sourceCategory {
            data["sourceCategory"] = sourceCategory
        }

        try await ref.setData(data)

        let optimistic = Entry(
            id: ref.documentID,
            text: trimmed,
            createdAt: Date(),
            sent: false,
            deleted: false
        )

        entries.removeAll { $0.id == optimistic.id }
        entries.insert(optimistic, at: 0)
        return optimistic
    }

    func hasActiveEntryMatching(_ text: String) -> Bool {
        let normalized = normalizedEntryText(text)
        return activeEntries.contains { normalizedEntryText($0.text) == normalized }
    }

    func isReminderDeleted(_ reminder: LastReminder) -> Bool {
        if let entryId = reminder.entryId,
           let entry = entries.first(where: { $0.id == entryId }) {
            return entry.deleted
        }

        let normalized = normalizedEntryText(reminder.text)
        return entries.contains { entry in
            entry.deleted && normalizedEntryText(entry.text) == normalized
        }
    }

    func softDeleteReminderFromBank(_ reminder: LastReminder) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(
                domain: "ReMindEntries",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Sign in required."]
            )
        }

        guard let entryId = try await entryIDForReminder(reminder, uid: uid) else {
            throw NSError(
                domain: "ReMindEntries",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "I couldn't find this reminder in your bank."]
            )
        }

        try await db.collection("users")
            .document(uid)
            .collection("entries")
            .document(entryId)
            .setData([
                "deleted": true,
                "deletedAt": FieldValue.serverTimestamp()
            ], merge: true)

        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].deleted = true
            entries[index].deletedAt = Date()
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
        let deleted = data["deleted"] as? Bool ?? data["archived"] as? Bool ?? false
        let deletedAt = (data["deletedAt"] as? Timestamp)?.dateValue()

        return Entry(
            id: doc.documentID,
            text: text,
            createdAt: ts,
            sentAt: sentAt,
            sent: sent,
            deleted: deleted,
            deletedAt: deletedAt
        )
    }

    private func entryIDForReminder(_ reminder: LastReminder, uid: String) async throws -> String? {
        if let entryId = reminder.entryId, !entryId.isEmpty {
            return entryId
        }

        let normalized = normalizedEntryText(reminder.text)
        if let local = entries
            .filter({ !$0.deleted && normalizedEntryText($0.text) == normalized })
            .max(by: { lhs, rhs in
                (lhs.sentAt ?? lhs.createdAt ?? .distantPast) < (rhs.sentAt ?? rhs.createdAt ?? .distantPast)
            }) {
            return local.id
        }

        let snapshot = try await db.collection("users")
            .document(uid)
            .collection("entries")
            .whereField("text", isEqualTo: reminder.text)
            .limit(to: 10)
            .getDocuments()

        return snapshot.documents
            .compactMap(mapEntry)
            .filter { !$0.deleted }
            .max(by: { lhs, rhs in
                (lhs.sentAt ?? lhs.createdAt ?? .distantPast) < (rhs.sentAt ?? rhs.createdAt ?? .distantPast)
            })?
            .id
    }

    private func normalizedEntryText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
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
