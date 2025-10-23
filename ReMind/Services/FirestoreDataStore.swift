// ================================
// File: Services/FirestoreDataStore.swift
// ================================
import Foundation
import FirebaseAuth
import FirebaseFirestore

public final class FirestoreDataStore: DataStore, @unchecked Sendable {
    private let db: Firestore

    public init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    // MARK: - Helpers
    
    // Gets UID from Firebase Auth
    private func requireUID() throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
    }

    // Builder for a user's document
    private func userDoc(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    // Builder for the user's collection of entries
    private func entriesCol(_ uid: String) -> CollectionReference {
        // IMPORTANT: use "entries" to match your Firestore rules
        userDoc(uid).collection("entries")
    }

    // MARK: - User Profile

    // Insert/update basic user fields
    public func createOrUpdateUser(_ profile: UserProfile) async throws {
        try await userDoc(profile.uid).setData([
            "uid": profile.uid,
            "phoneE164": profile.phoneE164,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // Reads signed-in user to return phone number and uid
    public func currentUser() async throws -> UserProfile? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let snap = try await userDoc(uid).getDocument()
        guard snap.exists else { return nil }
        let data = snap.data() ?? [:]
        let phone = data["phoneE164"] as? String ?? ""
        return UserProfile(uid: uid, phoneE164: phone)
    }

    // MARK: - Entries

    // Ensures signed in, then creates a new entry document
    public func addEntry(_ text: String) async throws -> Entry {
        let uid = try requireUID()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let doc = entriesCol(uid).document()
        try await doc.setData([
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp(),
            "sent": false
        ])

        // Local model (createdAt will be resolved on next fetch)
        return Entry(
            id: doc.documentID,
            text: trimmed,
            createdAt: Date(),
            sent: false
        )
    }

    // Ensures signed in, then queries entries by created date (newest first)
    public func listEntries() async throws -> [Entry] {
        let uid = try requireUID()
        let qs = try await entriesCol(uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return qs.documents.map { doc in
            let data = doc.data()
            let text = data["text"] as? String ?? ""
            let ts = data["createdAt"] as? Timestamp
            let sent = data["sent"] as? Bool ?? false

            return Entry(
                id: doc.documentID,
                text: text,
                createdAt: ts?.dateValue(),
                sent: sent
            )
        }
    }

    // Sets "sent" to true after a message is sent
    public func markDelivered(id: String) async throws {
        let uid = try requireUID()
        try await entriesCol(uid).document(id).updateData(["sent": true])
    }
}
