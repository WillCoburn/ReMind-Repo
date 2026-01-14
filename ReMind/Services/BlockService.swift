import Foundation
import FirebaseAuth
import FirebaseFirestore

protocol BlockService {
    func block(authorId: String) async throws
    func fetchBlockedAuthorIds() async throws -> Set<String>
    func listenBlockedAuthorIds(onChange: @escaping (Set<String>) -> Void) -> ListenerRegistration
}

enum BlockServiceError: Error {
    case unauthenticated
}

struct FirestoreBlockService: BlockService {
    private let db = Firestore.firestore()

    func block(authorId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw BlockServiceError.unauthenticated
        }

        let data: [String: Any] = [
            "blockedAt": FieldValue.serverTimestamp(),
            "reason": "user_initiated"
        ]

        try await db.collection("users")
            .document(uid)
            .collection("blockedUsers")
            .document(authorId)
            .setData(data, merge: true)
    }

    func fetchBlockedAuthorIds() async throws -> Set<String> {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw BlockServiceError.unauthenticated
        }

        let snapshot = try await db.collection("users")
            .document(uid)
            .collection("blockedUsers")
            .getDocuments()

        return Set(snapshot.documents.map { $0.documentID })
    }

    func listenBlockedAuthorIds(onChange: @escaping (Set<String>) -> Void) -> ListenerRegistration {
        guard let uid = Auth.auth().currentUser?.uid else {
            return db.collection("users")
                .document("unknown")
                .collection("blockedUsers")
                .addSnapshotListener { _, _ in
                    onChange([])
                }
        }

        return db.collection("users")
            .document(uid)
            .collection("blockedUsers")
            .addSnapshotListener { snapshot, _ in
                guard let snapshot = snapshot else {
                    onChange([])
                    return
                }

                let ids = Set(snapshot.documents.map { $0.documentID })
                onChange(ids)
            }
    }
}
