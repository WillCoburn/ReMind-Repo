import SwiftUI

struct CommunityPostRow: View {
    let post: CommunityPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.text)
                .font(.body)

            HStack(spacing: 16) {
                Label("\(post.likeCount)", systemImage: "hand.thumbsup")
                    .font(.caption)

                Button {
                    // TODO: like
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    // TODO: report
                } label: {
                    Image(systemName: "flag")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Spacer()

                // time since posted later (e.g., "3h ago")
            }
            .foregroundColor(.secondary)
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
