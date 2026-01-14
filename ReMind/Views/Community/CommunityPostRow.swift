import SwiftUI

struct CommunityPostRow: View {
    let post: CommunityPost
    let isLiked: Bool
    let isReported: Bool

    var onLike: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var onBlock: (() -> Void)? = nil

    @State private var showBlockConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text(post.text)
                .font(.body)
                .foregroundColor(.black)

        
            HStack(spacing: 12) {

                // LIKE
                Button {
                    onLike?()
                } label: {
                    Label(
                        "\(post.likeCount)",
                        systemImage: isLiked ? "heart.fill" : "heart"
                    )
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundColor(.figmaBlue)
                }
                .buttonStyle(PlainButtonStyle())

                // REPORT
                Button {
                    onReport?()
                } label: {
                    Label(
                        "\(post.reportCount)",
                        systemImage: isReported ? "flag.fill" : "flag"
                    )
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundColor(.figmaBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
                
                Label(timeAgoString(from: post.createdAt), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.9))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.paletteIvory.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.figmaBlue, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if !post.authorId.isEmpty {
                Menu {
                    Button(role: .destructive) {
                        showBlockConfirm = true
                    } label: {
                        Label("Block user", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray.opacity(0.7))
                }
                // Match the card’s content inset (same “right padding” feel as timestamp)
                .padding(.trailing, 16)
                // Nudge down from the top border so it feels aligned with your top content
                .padding(.top, 12)
            }
        }
        .alert(
            "Block user?",
            isPresented: $showBlockConfirm,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Block", role: .destructive) {
                    onBlock?()
                }
            },
            message: {
                Text("You won’t see any more posts from this user.")
            }
        )
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86_400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86_400))d ago"
        }
    }
}
