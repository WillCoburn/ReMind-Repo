import SwiftUI
import FirebaseFirestore

struct CommunityView: View {
    @State private var posts: [CommunityPost] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showComposer = false
    @State private var actionErrorMessage: String?

    @State private var listener: ListenerRegistration?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if isLoading {
                ProgressView("Loading community…")
            } else if let errorMessage, !errorMessage.isEmpty {
                VStack(spacing: 8) {
                    Text("Something went wrong")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if posts.isEmpty {
                VStack(spacing: 12) {
                    Text("No posts yet")
                        .font(.headline)
                    Text("Be the first to share a reminder with the community.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: []) {
                        ForEach(posts) { post in
                            CommunityPostRow(
                                post: post,
                                onLike: { handleLike(post) },
                                onReport: { handleReport(post) }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    await refreshFeed()
                }
            }
        }
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showComposer = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showComposer) {
            CommunityComposerSheet()
        }
        .alert(
            "Action Failed",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { newValue in
                    if newValue == false { actionErrorMessage = nil }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    actionErrorMessage = nil
                }
            }, message: {
                Text(actionErrorMessage ?? "")
            }
        )
        
        .onAppear { startListeningIfNeeded() }
        .onDisappear { stopListening() }
    }

    private func startListeningIfNeeded() {
        guard listener == nil else { return }

        listener = CommunityAPI.shared.observeFeed { newPosts in
            self.posts = newPosts
            self.isLoading = false
            self.errorMessage = nil
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    
    private func handleLike(_ post: CommunityPost) {
        Task {
            do {
                try await CommunityAPI.shared.toggleLike(postId: post.id)            } catch {
                await MainActor.run {
                    actionErrorMessage = "Unable to like post. Please try again."
                }
            }
        }
    }

    private func handleReport(_ post: CommunityPost) {
        Task {
            do {
                try await CommunityAPI.shared.toggleReport(postId: post.id)
            } catch {
                await MainActor.run {
                    actionErrorMessage = "Unable to report post. Please try again."
                }
            }
        }
    }

    private func refreshFeed() async {
        do {
            let latest = try await CommunityAPI.shared.fetchLatest()
            await MainActor.run {
                posts = latest
                isLoading = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        switch self {
        case .none: return true
        case .some(let s): return s.isEmpty
        }
    }
}
