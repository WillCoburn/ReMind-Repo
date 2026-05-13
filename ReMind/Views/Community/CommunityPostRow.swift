import SwiftUI

struct CommunityPostRow: View {
    let post: CommunityPost
    let isLiked: Bool
    let isReported: Bool

    var onLike: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var onOpenThread: (() -> Void)? = nil
    var onBlock: (() -> Void)? = nil
    var showsActions: Bool = true
    var showsThreadAction: Bool = true

    @State private var showBlockConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text(post.text)
                .font(.body)
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                horizontalMetaRow
                verticalMetaRow
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
            if !post.authorId.isEmpty, onBlock != nil {
                Menu {
                    Button(role: .destructive) {
                        showBlockConfirm = true
                    } label: {
                        Label("Block User", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray.opacity(0.7))
                        .frame(width: 44, height: 44, alignment: .center) // 👈 Apple-friendly hitbox
                        .contentShape(Rectangle())
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
        .dynamicTypeSize(.xSmall ... .xxLarge)
    }

    private var horizontalMetaRow: some View {
        HStack(spacing: 10) {
            actionButtons

            Spacer(minLength: 8)

            timestampLabel
        }
    }

    private var verticalMetaRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            actionButtons
            timestampLabel
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if showsActions {
                Button {
                    onLike?()
                } label: {
                    metaLabel("\(post.likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                }
                .buttonStyle(PlainButtonStyle())
            }

            if showsActions {
                Button {
                    onReport?()
                } label: {
                    metaLabel("\(post.reportCount)", systemImage: isReported ? "flag.fill" : "flag")
                }
                .buttonStyle(PlainButtonStyle())
            }

            if showsThreadAction {
                Button {
                    onOpenThread?()
                } label: {
                    metaLabel("\(post.commentCount)", systemImage: "text.bubble")
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var timestampLabel: some View {
        Label(timeAgoString(from: post.createdAt), systemImage: "clock")
            .font(.caption)
            .foregroundColor(.gray.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }

    private func metaLabel(_ title: String, systemImage: String) -> some View {
        CommunityCountActionLabel(title: title, systemImage: systemImage)
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

struct CommunityCountActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 16, height: 16)

            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(minWidth: 18, alignment: .leading)
        }
        .foregroundColor(.figmaBlue)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(minWidth: 54, minHeight: 34, alignment: .center)
        .contentShape(Rectangle())
        .fixedSize(horizontal: true, vertical: false)
        .dynamicTypeSize(.xSmall ... .xxLarge)
    }
}
