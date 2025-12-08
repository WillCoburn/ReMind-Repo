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
    @State private var isAtTop = true

    var body: some View {
        ZStack {
            
            // background color
            Color.white.ignoresSafeArea()
            Color.blue.opacity(0.04).ignoresSafeArea()

            if isLoading {
                VStack(spacing: 20) {
                     header
                     ProgressView("Loading community…")
                         .tint(.paletteTurquoise)
                 }

            } else if let errorMessage, !errorMessage.isEmpty {
                VStack(spacing: 12) {
                    header
                    VStack(spacing: 8) {
                        Text("Something went wrong")
                            .foregroundColor(.palettePewter)
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.palettePewter.opacity(0.8))
                    }
                    .padding(.horizontal)
                }


            } else if posts.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        header
                        if appVM.isGodModeUser {
                            GodModeBanner()
                                .padding(.horizontal)
                        }
                        Text("No posts yet")
                            .font(.headline)
                            .foregroundColor(.palettePewter)
                        Text("Be the first to share a reminder with the community.")
                            .font(.subheadline)
                            .foregroundColor(.palettePewter.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                        .frame(maxWidth: .infinity)
                }

            } else {


                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                         header
                         if appVM.isGodModeUser {
                             GodModeBanner()
                                 .padding(.horizontal)
                                 .padding(.bottom, 8)
                         }

                         GeometryReader { proxy in
                             Color.clear
                                 .preference(key: ScrollOffsetPreferenceKey.self,
                                             value: proxy.frame(in: .named("communityScroll")).minY)
                         }
                         .frame(height: 0)

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
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .refreshable {
                    await refreshFeed()
                }
                .coordinateSpace(name: "communityScroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minY in
                    isAtTop = minY >= 0
                }
            }
        }

        .overlay(alignment: .bottomTrailing) {
            Button {
                showComposer = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                        
                        //BUTTON COLOR
                            .fill(Color.figmaBlue)
                    )
                    .shadow(radius: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
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
        // Hide the nav bar so the custom header/background fill the safe areas.
                .toolbar(.hidden, for: .navigationBar)
    }
    
    private var header: some View {
        Text("Community")
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 36)
            .padding(.bottom, 40)
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
        let previouslyLiked = likedPostIds.contains(post.id)

        if !godModeEnabled {
            // Optimistically update UI so the heart fills immediately
            Task { await MainActor.run { applyLikeState(for: post, isLiked: !previouslyLiked) } }
        }

        
        Task {
            do {
                try await CommunityAPI.shared.toggleLike(postId: post.id)
                if godModeEnabled {
                    await refreshFeed()

                }
            } catch {
                if !godModeEnabled {
                    // Roll back optimistic update
                    await MainActor.run { applyLikeState(for: post, isLiked: previouslyLiked) }
                }
                await MainActor.run {
                    actionErrorMessage = "Unable to like post. Please try again."
                }
            }
        }
    }

    private func handleReport(_ post: CommunityPost) {
        let godModeEnabled = appVM.isGodModeUser
        let previouslyReported = reportedPostIds.contains(post.id)

        if !godModeEnabled {
            // Optimistically update UI so the flag fills immediately
            Task { await MainActor.run { applyReportState(for: post, isReported: !previouslyReported) } }
        }

        Task {
            do {
                try await CommunityAPI.shared.toggleReport(postId: post.id)
                if godModeEnabled {
                    await refreshFeed()

                }
            } catch {
                await MainActor.run {
                    if !godModeEnabled {
                        // Roll back optimistic update
                        applyReportState(for: post, isReported: previouslyReported)
                    }
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
    
    // MARK: - Optimistic UI helpers

    @MainActor
    private func applyLikeState(for post: CommunityPost, isLiked: Bool) {
        if isLiked {
            likedPostIds.insert(post.id)
        } else {
            likedPostIds.remove(post.id)
        }

        updatePosts(for: post.id) { current in
            current.withUpdatedCounts(likeDelta: isLiked ? 1 : -1)
        }
    }

    @MainActor
    private func applyReportState(for post: CommunityPost, isReported: Bool) {
        if isReported {
            reportedPostIds.insert(post.id)
        } else {
            reportedPostIds.remove(post.id)
        }

        updatePosts(for: post.id) { current in
            current.withUpdatedCounts(reportDelta: isReported ? 1 : -1)
        }
    }

    @MainActor
    private func updatePosts(for postId: String, transform: (CommunityPost) -> CommunityPost) {
        posts = posts.map { post in
            guard post.id == postId else { return post }
            return transform(post)
        }
    }
}

private extension CommunityPost {
    func withUpdatedCounts(likeDelta: Int = 0, reportDelta: Int = 0) -> CommunityPost {
        CommunityPost(
            id: id,
            text: text,
            createdAt: createdAt,
            likeCount: max(0, likeCount + likeDelta),
            reportCount: max(0, reportCount + reportDelta),
            isHidden: isHidden,
            expiresAt: expiresAt
        )
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
                .fill(Color.figmaBlue)
        )
    }
}


private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension Color {
    static let communityBackground = Color(
        red: 252.0 / 255.0,
        green: 248.0 / 255.0,
        blue: 246.0 / 255.0
    )
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        switch self {
        case .none: return true
        case .some(let s): return s.isEmpty
        }
    }
}
