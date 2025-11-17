import SwiftUI
import FirebaseFirestore

struct CommunityView: View {
    @State private var posts: [CommunityPost] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showComposer = false

    @State private var listener: ListenerRegistration?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if isLoading {
                ProgressView("Loading community…")
            } else if !errorMessage.isNilOrEmpty {
                VStack(spacing: 8) {
                    Text("Something went wrong")
                        .font(.headline)
                    Text(errorMessage ?? "")
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
                List {
                    ForEach(posts) { post in
                        CommunityPostRow(post: post)
                    }
                }
                .listStyle(.plain)
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
        .onAppear { startListeningIfNeeded() }
        .onDisappear { stopListening() }
    }

    private func startListeningIfNeeded() {
        guard listener == nil else { return }

        listener = CommunityAPI.shared.observeFeed { newPosts in
            self.posts = newPosts
            self.isLoading = false
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
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
