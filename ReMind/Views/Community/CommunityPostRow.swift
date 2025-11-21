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
                .foregroundColor(.black)

            // Timestamp
            HStack(spacing: 12) {
                Label(timeAgoString(from: post.createdAt), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.9))

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
                            .fill(Color.paletteTurquoise.opacity(isLiked ? 0.3 : 0.15))
                    )
                    .foregroundColor(.palettePewter)
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
                            .fill(Color.paletteTurquoise.opacity(isReported ? 0.3 : 0.15))
                    )
                    .foregroundColor(.palettePewter)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.paletteIvory.opacity(0.9))
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
