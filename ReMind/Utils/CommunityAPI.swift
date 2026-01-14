// ============================
// File: Services/Community/CommunityAPI.swift
// ============================
import Foundation
import FirebaseFirestore
import FirebaseFunctions

struct CommunityPost: Identifiable, Hashable {
    let id: String
    let authorId: String
    let text: String
    let createdAt: Date
    let likeCount: Int
    let reportCount: Int
    let isHidden: Bool
    let expiresAt: Date
    
    init(
         id: String,
         authorId: String,
         text: String,
         createdAt: Date,
         likeCount: Int,
         reportCount: Int,
         isHidden: Bool,
         expiresAt: Date
     ) {
         self.id = id
         self.authorId = authorId
         self.text = text
         self.createdAt = createdAt
         self.likeCount = likeCount
         self.reportCount = reportCount
         self.isHidden = isHidden
         self.expiresAt = expiresAt
     }

    init?(from doc: DocumentSnapshot) {
        guard let data = doc.data() else { return nil }
        guard let text = data["text"] as? String,
              let authorId = data["authorId"] as? String,
              let createdAtTs = data["createdAt"] as? Timestamp,
              let expiresAtTs = data["expiresAt"] as? Timestamp else {
            return nil
        }

        self.id = doc.documentID
        self.authorId = authorId
        self.text = text
        self.createdAt = createdAtTs.dateValue()
        self.expiresAt = expiresAtTs.dateValue()
        self.likeCount = data["likeCount"] as? Int ?? 0
        self.reportCount = data["reportCount"] as? Int ?? 0
        self.isHidden = data["isHidden"] as? Bool ?? false
    }
}

final class CommunityAPI {
    static let shared = CommunityAPI()
    private init() {}

    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    // MARK: - Feed subscription

    func observeFeed(
        onChange: @escaping ([CommunityPost]) -> Void
    ) -> ListenerRegistration {
        db.collection("communityPosts")
            .whereField("isHidden", isEqualTo: false)
            .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("[CommunityAPI] observeFeed error:", error)
                    onChange([])
                    return
                }
                guard let snapshot = snapshot else {
                    onChange([])
                    return
                }

                let posts: [CommunityPost] = snapshot.documents.compactMap {
                    CommunityPost(from: $0)
                }
                onChange(posts)
            }
    }

    func fetchLatest() async throws -> [CommunityPost] {
        let snapshot = try await db.collection("communityPosts")
            .whereField("isHidden", isEqualTo: false)
            .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { CommunityPost(from: $0) }
    }
    
    
    // MARK: - Actions

    func createPost(text: String) async throws {
        let data: [String: Any] = ["text": text]
        _ = try await functions.httpsCallable("createCommunityPost").call(data)
    }

    func toggleLike(postId: String) async throws {
        let data: [String: Any] = ["postId": postId]
        _ = try await functions.httpsCallable("toggleCommunityLike").call(data)
    }

    func toggleReport(postId: String) async throws {
        let data: [String: Any] = ["postId": postId]
        _ = try await functions.httpsCallable("toggleCommunityReport").call(data)
    }
}
