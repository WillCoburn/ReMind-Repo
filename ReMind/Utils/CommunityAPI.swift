import Foundation
import FirebaseFunctions
import FirebaseFirestore

struct CommunityPost: Identifiable, Codable {
    let id: String
    let text: String
    let createdAt: Date
    let likeCount: Int
    let reportCount: Int
    let isHidden: Bool
    let expiresAt: Date
}

final class CommunityAPI {
    static let shared = CommunityAPI()
    private init() {}

    private lazy var functions = Functions.functions()
    private let db = Firestore.firestore()

    // MARK: - Feed

    func observeFeed(completion: @escaping ([CommunityPost]) -> Void) -> ListenerRegistration {
        return db.collection("communityPosts")
            .whereField("isHidden", isEqualTo: false)
            .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                // parse into [CommunityPost]; you can fill this in later
            }
    }

    // MARK: - Actions

    func createPost(text: String) async throws {
        // will call callable "createCommunityPost"
    }

    func like(postId: String) async throws {
        // callable "likeCommunityPost"
    }

    func report(postId: String) async throws {
        // callable "reportCommunityPost"
    }

    func save(postId: String) async throws {
        // callable "saveCommunityPost"
    }
}
