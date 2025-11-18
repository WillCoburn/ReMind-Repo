import SwiftUI
import FirebaseFirestore
import FirebaseFunctions

struct CommunityView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @State private var posts: [CommunityPost] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showComposer = false
    @State private var actionErrorMessage: String?
    @State private var reportLimitMessage: String?

    @State private var likedPostIds: Set<String> = []
    @State private var reportedPostIds: Set<String> = []

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
                    if appVM.isGodModeUser {
                        GodModeBanner()
                    }
                    Text("No posts yet")
                        .font(.headline)
                    Text("Be the first to share a reminder with the community.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

            } else {
                if appVM.isGodModeUser {
                    GodModeBanner()
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(posts) { post in
                            CommunityPostRow(
                                post: post,
                                isLiked: isLiked(post),
                                isReported: isReported(post),
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
                Button { showComposer = true } label: {
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
                set: { if !$0 { actionErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) { actionErrorMessage = nil }
            },
            message: { Text(actionErrorMessage ?? "") }
        )
        .alert(
            "Reports Temporarily Limited",
            isPresented: Binding(
                get: { reportLimitMessage != nil },
                set: { if !$0 { reportLimitMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) { reportLimitMessage = nil }
            },
            message: {
                Text(reportLimitMessage ?? "Reports are limited to avoid report-spamming. Please try again later.")
            }
        )
        .onAppear { startListeningIfNeeded() }
        .onDisappear { stopListening() }
    }

    // MARK: - Firestore Feed Listener

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

    // MARK: - Actions

    private func handleLike(_ post: CommunityPost) {
        let godModeEnabled = appVM.isGodModeUser
        Task {
            do {
                try await CommunityAPI.shared.toggleLike(postId: post.id)
                if godModeEnabled {
                    await refreshFeed()
                } else {
                    await MainActor.run {
                        toggle(id: post.id, in: &likedPostIds)
                    }
                }
            } catch {
                await MainActor.run {
                    actionErrorMessage = "Unable to like post. Please try again."
                }
            }
        }
    }

    private func handleReport(_ post: CommunityPost) {
        let godModeEnabled = appVM.isGodModeUser
        Task {
            do {
                try await CommunityAPI.shared.toggleReport(postId: post.id)
                if godModeEnabled {
                    await refreshFeed()
                } else {
                    await MainActor.run {
                        toggle(id: post.id, in: &reportedPostIds)
                    }
                }
            } catch {
                await MainActor.run {
                    if let limitMessage = reportLimitAlertMessage(for: error) {
                        reportLimitMessage = limitMessage
                    } else {
                        actionErrorMessage = "Unable to report post. Please try again."
                    }
                }
            }
        }
    }

    private func isLiked(_ post: CommunityPost) -> Bool {
        guard !appVM.isGodModeUser else { return false }
        return likedPostIds.contains(post.id)
    }

    private func isReported(_ post: CommunityPost) -> Bool {
        guard !appVM.isGodModeUser else { return false }
        return reportedPostIds.contains(post.id)
    }

    @MainActor
    private func toggle(id: String, in set: inout Set<String>) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
    }

    // MARK: - Refresh

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

    private func reportLimitAlertMessage(for error: Error) -> String? {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code),
              code == .resourceExhausted else {
            return nil
        }

        if let details = nsError.userInfo[FunctionsErrorDetailsKey] as? String,
           !details.isEmpty {
            return details
        }

        return "Reports are limited to avoid report-spamming. Please try again later."
    }
}

private struct GodModeBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .foregroundColor(.yellow)
            Text("God mode enabled: unlimited posts, likes, and reports.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
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
