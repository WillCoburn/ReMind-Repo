import SwiftUI
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

struct CommunityView: View {
    @EnvironmentObject private var appVM: AppViewModel
    @ObservedObject private var revenueCat: RevenueCatManager = .shared
    private let blockService: BlockService = FirestoreBlockService()
    @State private var posts: [CommunityPost] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showComposer = false
    @State private var actionErrorMessage: String?
    @State private var reportLimitMessage: String?

    @State private var likedPostIds: Set<String> = []
    @State private var reportedPostIds: Set<String> = []
    @State private var blockedAuthorIds: Set<String> = []

    @State private var listener: ListenerRegistration?
    @State private var blockListener: ListenerRegistration?
    @State private var isAtTop = true
    @State private var isStartingListener = false
    @State private var selectedPostForThread: CommunityPost?

    private var isUserActive: Bool { true }

    var body: some View {
        // Observe RevenueCat directly so entitlement changes update interaction instantly.
        let _ = revenueCat.entitlementActive
        ZStack(alignment: .bottomTrailing) {
            content

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
        .sheet(item: $selectedPostForThread) { post in
            NavigationStack {
                CommunityThreadView(post: post)
            }
        }
        // Hide the nav bar so the custom header/background fill the safe areas.
        .toolbar(.hidden, for: .navigationBar)
    }

    private var content: some View {
        ZStack {
            
            // background color
            Color.white.ignoresSafeArea()
            Color.blue.opacity(0.04).ignoresSafeArea()

            if isLoading {
                VStack(spacing: 20) {
                    header
                    ProgressView("Loading…")
                        .foregroundColor(.black)
                }

            } else if let errorMessage, !errorMessage.isEmpty {
                VStack(spacing: 12) {
                    header
                    VStack(spacing: 8) {
                        Text("Something went wrong")
                            .foregroundColor(.black)
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
                                    onReport: { handleReport(post) },
                                    onOpenThread: {
                                        selectedPostForThread = post
                                    },
                                    onBlock: {
                                        Task {
                                            await blockAuthor(post.authorId)
                                        }
                                    }
                                )
                                .blur(radius: isUserActive ? 0 : 12)
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
        guard listener == nil, !isStartingListener else { return }
        isStartingListener = true
        isLoading = true

        Task {
            do {
                let blocked = try await blockService.fetchBlockedAuthorIds()
                await MainActor.run {
                    blockedAuthorIds = blocked
                }
                await MainActor.run {
                    startFeedListener()
                    startBlockedUsersListener()
                    isStartingListener = false
                }
            } catch {
                await MainActor.run {
                    blockedAuthorIds = []
                    startFeedListener()
                    startBlockedUsersListener()
                    isStartingListener = false
                }
            }
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
        blockListener?.remove()
        blockListener = nil
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
                posts = filteredPosts(latest)
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

    private func startFeedListener() {
        listener = CommunityAPI.shared.observeFeed { newPosts in
            let filtered = filteredPosts(newPosts)
            self.posts = filtered
            self.isLoading = false
            self.errorMessage = nil
        }
    }

    private func startBlockedUsersListener() {
        blockListener = blockService.listenBlockedAuthorIds { newBlockedIds in
            Task { @MainActor in
                blockedAuthorIds = newBlockedIds
                posts = posts.filter { !newBlockedIds.contains($0.authorId) }
            }
        }
    }

    private func filteredPosts(_ posts: [CommunityPost]) -> [CommunityPost] {
        posts.filter { post in
            !post.isHidden && !blockedAuthorIds.contains(post.authorId)
        }
    }

    private func blockAuthor(_ authorId: String) async {
        guard !authorId.isEmpty else { return }
        let previousBlocked = blockedAuthorIds
        let previousPosts = posts

        await MainActor.run {
            blockedAuthorIds.insert(authorId)
            posts = posts.filter { $0.authorId != authorId }
        }

        do {
            try await blockService.block(authorId: authorId)
        } catch {
            await MainActor.run {
                blockedAuthorIds = previousBlocked
                posts = previousPosts
                actionErrorMessage = "Couldn’t block user. Check connection and try again."
            }
        }
    }
}

private extension CommunityPost {
    func withUpdatedCounts(likeDelta: Int = 0, reportDelta: Int = 0) -> CommunityPost {
        CommunityPost(
            id: id,
            authorId: authorId,
            text: text,
            createdAt: createdAt,
            likeCount: max(0, likeCount + likeDelta),
            reportCount: max(0, reportCount + reportDelta),
            commentCount: commentCount,
            isHidden: isHidden,
            expiresAt: expiresAt
        )
    }
}

private struct CommunityThreadView: View {
    let post: CommunityPost

    @EnvironmentObject private var appVM: AppViewModel
    private let blockService: BlockService = FirestoreBlockService()
    private let currentUserId = Auth.auth().currentUser?.uid
    @State private var allComments: [CommunityComment] = []
    @State private var comments: [CommunityComment] = []
    @State private var blockedAuthorIds: Set<String> = []
    @State private var listener: ListenerRegistration?
    @State private var blockedListener: ListenerRegistration?
    @State private var newCommentText: String = ""
    @State private var sendError: String?
    @State private var commentsLoadError: String?
    @State private var hasLoadedInitialCommentsSnapshot = false
    @State private var isSending = false
    @State private var likedCommentIds: Set<String> = []
    @State private var reportedCommentIds: Set<String> = []

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Color.blue.opacity(0.04).ignoresSafeArea()

            VStack(spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        CommunityPostRow(post: post, isLiked: false, isReported: false)
                            .allowsHitTesting(false)

                        if comments.isEmpty {
                            Text(emptyStateMessage)
                                .font(.subheadline)
                                .foregroundColor(Color.black.opacity(0.75))
                                .padding(.vertical, 8)
                        } else {
                            ForEach(comments) { comment in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(comment.text)
                                        .foregroundColor(.black)
                                    HStack(spacing: 12) {
                                        Button {
                                            handleCommentLike(comment)
                                        } label: {
                                            Label(
                                                "\(comment.likeCount)",
                                                systemImage: isCommentLiked(comment.id) ? "heart.fill" : "heart"
                                            )
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .foregroundColor(.figmaBlue)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            handleCommentReport(comment)
                                        } label: {
                                            Label(
                                                "\(comment.reportCount)",
                                                systemImage: isCommentReported(comment.id) ? "flag.fill" : "flag"
                                            )
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .foregroundColor(.figmaBlue)
                                        }
                                        .buttonStyle(.plain)

                                        Spacer()

                                        Label(timeAgoString(from: comment.createdAt), systemImage: "clock")
                                            .font(.caption)
                                            .foregroundColor(.gray.opacity(0.9))
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.paletteIvory.opacity(0.9))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.figmaBlue.opacity(0.5), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                VStack(spacing: 8) {
                    TextField("", text: $newCommentText, axis: .vertical)
                        .lineLimit(1...5)
                        .foregroundColor(.black)
                        .tint(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.paletteIvory.opacity(0.9))
                        )
                        .overlay(alignment: .leading) {
                            if newCommentText.isEmpty {
                                Text("Write a reply…")
                                    .foregroundColor(Color.black.opacity(0.65))
                                    .padding(.horizontal, 14)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.figmaBlue, lineWidth: 1)
                        )

                    Button {
                        Task { await sendComment() }
                    } label: {
                        if isSending {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .tint(.white)
                        } else {
                            Text("Reply")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.figmaBlue)
                    .disabled(isSending || newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(
                    Color.white.opacity(0.94)
                        .overlay(Color.blue.opacity(0.04))
                )
            }
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startListeners()
        }
        .onDisappear {
            listener?.remove()
            blockedListener?.remove()
        }
        .alert(
            "Unable to send reply",
            isPresented: Binding(
                get: { sendError != nil },
                set: { if !$0 { sendError = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) { sendError = nil }
            },
            message: { Text(sendError ?? "Please try again.") }
        )
    }

    private func startListeners() {
        commentsLoadError = nil
        hasLoadedInitialCommentsSnapshot = false

        listener = CommunityAPI.shared.observeComments(
            postId: post.id,
            onChange: { newComments in
                Task { @MainActor in
                    hasLoadedInitialCommentsSnapshot = true
                    allComments = newComments
                    comments = filteredComments(from: newComments)
                    syncCommentInteractionState(for: comments)
                    if post.commentCount > 0 && newComments.isEmpty {
                        print(
                            "[CommunityThreadView] post=\(post.id) has commentCount=\(post.commentCount) but listener returned 0 comments."
                        )
                    }
                }
            },
            onError: { error in
                Task { @MainActor in
                    hasLoadedInitialCommentsSnapshot = true
                    commentsLoadError = error?.localizedDescription
                }
            }
        )

        blockedListener = blockService.listenBlockedAuthorIds { ids in
            Task { @MainActor in
                blockedAuthorIds = ids
                comments = filteredComments(from: allComments)
                syncCommentInteractionState(for: comments)
            }
        }
    }

    private func sendComment() async {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        await MainActor.run { isSending = true }

        do {
            try await CommunityAPI.shared.createComment(postId: post.id, text: text)
            await MainActor.run {
                newCommentText = ""
                isSending = false
            }
        } catch {
            await MainActor.run {
                sendError = "Please check your connection and try again."
                isSending = false
            }
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86_400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86_400))d ago"
    }

    private func filteredComments(from source: [CommunityComment]) -> [CommunityComment] {
        source.filter { comment in
            if comment.isHidden {
                return false
            }
            guard !comment.authorId.isEmpty else { return true }
            if let currentUserId, comment.authorId == currentUserId {
                return true
            }
            return !blockedAuthorIds.contains(comment.authorId)
        }
    }

    private func handleCommentLike(_ comment: CommunityComment) {
        let godModeEnabled = appVM.isGodModeUser
        Task {
            do {
                try await CommunityAPI.shared.toggleCommentLike(postId: post.id, commentId: comment.id)
                if godModeEnabled {
                    await MainActor.run {
                        syncCommentInteractionState(for: comments)
                    }
                }
            } catch {
                let nsError = error as NSError
                print("[CommunityThreadView] like failed post=\(post.id) comment=\(comment.id) domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)")
                await MainActor.run {
                    sendError = "Couldn't update like right now. Please try again."
                }
            }
        }
    }

    private func handleCommentReport(_ comment: CommunityComment) {
        let godModeEnabled = appVM.isGodModeUser
        Task {
            do {
                try await CommunityAPI.shared.toggleCommentReport(postId: post.id, commentId: comment.id)
                if godModeEnabled {
                    await MainActor.run {
                        syncCommentInteractionState(for: comments)
                    }
                }
            } catch {
                let nsError = error as NSError
                print("[CommunityThreadView] flag failed post=\(post.id) comment=\(comment.id) domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)")
                await MainActor.run {
                    sendError = "Couldn't update flag right now. Please try again."
                }
            }
        }
    }

    private func isCommentLiked(_ commentId: String) -> Bool {
        guard !appVM.isGodModeUser else { return false }
        return likedCommentIds.contains(commentId)
    }

    private func isCommentReported(_ commentId: String) -> Bool {
        guard !appVM.isGodModeUser else { return false }
        return reportedCommentIds.contains(commentId)
    }

    private func syncCommentInteractionState(for comments: [CommunityComment]) {
        guard !appVM.isGodModeUser else {
            likedCommentIds = []
            reportedCommentIds = []
            return
        }

        guard let uid = currentUserId else {
            likedCommentIds = []
            reportedCommentIds = []
            return
        }
        let commentIds = comments.map(\.id)
        guard !commentIds.isEmpty else {
            likedCommentIds = []
            reportedCommentIds = []
            return
        }

        Task {
            let db = Firestore.firestore()
            var likedIds = Set<String>()
            var flaggedIds = Set<String>()

            await withTaskGroup(of: (String, Bool, Bool).self) { group in
                for commentId in commentIds {
                    group.addTask {
                        do {
                            let commentRef = db.collection("communityPosts")
                                .document(post.id)
                                .collection("comments")
                                .document(commentId)
                            async let likeSnap = commentRef.collection("likes").document(uid).getDocument()
                            async let flagSnap = commentRef.collection("flags").document(uid).getDocument()
                            let (resolvedLikeSnap, resolvedFlagSnap) = try await (likeSnap, flagSnap)
                            return (commentId, resolvedLikeSnap.exists, resolvedFlagSnap.exists)
                        } catch {
                            return (commentId, false, false)
                        }
                    }
                }

                for await (commentId, isLiked, isFlagged) in group {
                    if isLiked { likedIds.insert(commentId) }
                    if isFlagged { flaggedIds.insert(commentId) }
                }
            }

            await MainActor.run {
                likedCommentIds = likedIds
                reportedCommentIds = flaggedIds
            }
        }
    }

    private var emptyStateMessage: String {
        if !hasLoadedInitialCommentsSnapshot {
            return "Loading replies…"
        }
        if commentsLoadError != nil {
            return "Unable to load replies right now. Pull to refresh."
        }
        return "No replies yet. Start the discussion."
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
