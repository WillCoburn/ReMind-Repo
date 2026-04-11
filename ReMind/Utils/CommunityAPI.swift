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
    let commentCount: Int
    let isHidden: Bool
    let expiresAt: Date
    
    init(
         id: String,
         authorId: String,
         text: String,
         createdAt: Date,
         likeCount: Int,
         reportCount: Int,
         commentCount: Int,
         isHidden: Bool,
         expiresAt: Date
     ) {
         self.id = id
         self.authorId = authorId
         self.text = text
         self.createdAt = createdAt
         self.likeCount = likeCount
         self.reportCount = reportCount
         self.commentCount = commentCount
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
        self.commentCount = data["commentCount"] as? Int ?? 0
        self.isHidden = data["isHidden"] as? Bool ?? false
    }
}

struct CommunityComment: Identifiable, Hashable {
    let id: String
    let authorId: String
    let text: String
    let createdAt: Date

    init?(from doc: DocumentSnapshot) {
        guard let data = doc.data() else {
            return nil
        }

        let text = (data["text"] as? String)
            ?? (data["content"] as? String)
            ?? (data["body"] as? String)
            ?? (data["message"] as? String)
            ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let authorId = data["authorId"] as? String ?? ""
        let createdAt: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else if let date = data["createdAt"] as? Date {
            createdAt = date
        } else if let seconds = data["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: seconds)
        } else if let createdAtString = data["createdAt"] as? String,
                  let parsed = ISO8601DateFormatter().date(from: createdAtString) {
            createdAt = parsed
        } else {
            // Keep thread render resilient if a manually-created doc has no timestamp.
            createdAt = Date.distantPast
        }

        self.id = doc.documentID
        self.authorId = authorId
        self.text = text
        self.createdAt = createdAt
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

    func createComment(postId: String, text: String) async throws {
        let data: [String: Any] = [
            "postId": postId,
            "text": text,
        ]
        _ = try await functions.httpsCallable("createCommunityComment").call(data)
    }

    func observeComments(
        postId: String,
        onChange: @escaping ([CommunityComment]) -> Void
    ) -> ListenerRegistration {
        db.collection("communityPosts")
            .document(postId)
            .collection("comments")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("[CommunityAPI] observeComments error:", error)
                    onChange([])
                    return
                }
                guard let snapshot = snapshot else {
                    onChange([])
                    return
                }

                let comments = snapshot.documents
                    .compactMap { CommunityComment(from: $0) }
                    .sorted(by: { $0.createdAt < $1.createdAt })
                onChange(comments)
            }
    }
}
