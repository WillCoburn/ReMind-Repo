import SwiftUI

struct CommunityPostRow: View {
    let post: CommunityPost
    let isLiked: Bool
    let isReported: Bool

    var onLike: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text(post.text)
                .font(.body)
                .foregroundColor(.primary)

            // Timestamp
            HStack(spacing: 12) {
                Label(timeAgoString(from: post.createdAt), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Buttons
            HStack(spacing: 12) {
                Spacer()

                // LIKE
                Button {
                    onLike?()
                } label: {
                    Label(
                        "\(post.likeCount)",
                        systemImage: isLiked ? "arrow.up.square.fill" : "arrow.up.square"
                    )
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isLiked ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
                    )
                    .foregroundColor(isLiked ? Color.accentColor : Color(.tertiaryLabel))
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isReported ? Color.red.opacity(0.15) : Color(.systemGray5))
                    )
                    .foregroundColor(isReported ? .red : Color(.tertiaryLabel))
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
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
