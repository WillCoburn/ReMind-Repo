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

    init?(fromCallable data: [String: Any]) {
        guard let id = data["id"] as? String,
              let text = data["text"] as? String,
              let authorId = data["authorId"] as? String,
              let createdAtMillis = Self.numberValue(data["createdAtMillis"]),
              let expiresAtMillis = Self.numberValue(data["expiresAtMillis"]) else {
            return nil
        }

        self.id = id
        self.authorId = authorId
        self.text = text
        self.createdAt = Date(timeIntervalSince1970: createdAtMillis / 1000)
        self.expiresAt = Date(timeIntervalSince1970: expiresAtMillis / 1000)
        self.likeCount = Self.integerValue(data["likeCount"]) ?? 0
        self.reportCount = Self.integerValue(data["reportCount"]) ?? 0
        self.commentCount = Self.integerValue(data["commentCount"]) ?? 0
        self.isHidden = data["isHidden"] as? Bool ?? false
    }

    private static func numberValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private static func integerValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }
}

struct CommunityComment: Identifiable, Hashable {
    let id: String
    let authorId: String
    let text: String
    let createdAt: Date
    let likeCount: Int
    let reportCount: Int
    let isHidden: Bool

    init(
        id: String,
        authorId: String,
        text: String,
        createdAt: Date,
        likeCount: Int,
        reportCount: Int,
        isHidden: Bool
    ) {
        self.id = id
        self.authorId = authorId
        self.text = text
        self.createdAt = createdAt
        self.likeCount = max(0, likeCount)
        self.reportCount = max(0, reportCount)
        self.isHidden = isHidden
    }

    init?(from doc: DocumentSnapshot) {
        guard let data = doc.data() else {
            return nil
        }

        let text = Self.extractText(from: data)
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
        self.likeCount = data["likeCount"] as? Int ?? 0
        self.reportCount = data["reportCount"] as? Int ?? 0
        self.isHidden = data["isHidden"] as? Bool ?? false
    }

    private static func extractText(from data: [String: Any]) -> String {
        let candidates = ["text", "content", "body", "message"]
        for key in candidates {
            guard let raw = data[key] else { continue }
            if let value = raw as? String { return value }
            if let value = raw as? NSString { return value as String }
            if let nested = raw as? [String: Any] {
                if let value = nested["text"] as? String { return value }
                if let value = nested["value"] as? String { return value }
            }
        }
        return ""
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

    func createPost(text: String) async throws -> CommunityPost? {
        let data: [String: Any] = ["text": text]
        let result = try await functions.httpsCallable("createCommunityPost").call(data)
        guard let response = result.data as? [String: Any],
              let postData = response["post"] as? [String: Any] else {
            return nil
        }
        return CommunityPost(fromCallable: postData)
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

    func toggleCommentLike(postId: String, commentId: String) async throws {
        // Keep both keys during rollout so we remain compatible with backends
        // that still read `replyId` for sub-comment reactions.
        let data: [String: Any] = [
            "postId": postId,
            "commentId": commentId,
            "replyId": commentId,
        ]
        do {
            _ = try await functions.httpsCallable("toggleCommunityCommentLike").call(data)
        } catch {
            print("[CommunityAPI] toggleCommunityCommentLike failed post=\(postId) comment=\(commentId):", error)
            throw error
        }
    }

    func toggleCommentReport(postId: String, commentId: String) async throws {
        // Keep both keys during rollout so we remain compatible with backends
        // that still read `replyId` for sub-comment reactions.
        let data: [String: Any] = [
            "postId": postId,
            "commentId": commentId,
            "replyId": commentId,
        ]
        do {
            _ = try await functions.httpsCallable("toggleCommunityCommentReport").call(data)
        } catch {
            print("[CommunityAPI] toggleCommunityCommentReport failed post=\(postId) comment=\(commentId):", error)
            throw error
        }
    }

    func observeComments(
        postId: String,
        onChange: @escaping ([CommunityComment]) -> Void,
        onError: ((Error?) -> Void)? = nil
    ) -> ListenerRegistration {
        db.collection("communityPosts")
            .document(postId)
            .collection("comments")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("[CommunityAPI] observeComments error for post \(postId):", error)
                    onError?(error)
                    onChange([])
                    return
                }
                guard let snapshot = snapshot else {
                    print("[CommunityAPI] observeComments received nil snapshot for post \(postId)")
                    onChange([])
                    return
                }

                let mappedComments = snapshot.documents.map { doc in
                    CommunityComment(from: doc)
                }
                let decodeFailureCount = mappedComments.filter { $0 == nil }.count
                let comments = mappedComments
                    .compactMap { $0 }
                    .sorted(by: { $0.createdAt < $1.createdAt })
                print(
                    "[CommunityAPI] observeComments post=\(postId) raw=\(snapshot.documents.count) decoded=\(comments.count) decodeFailures=\(decodeFailureCount)"
                )
                onError?(nil)
                onChange(comments)
            }
    }
}
