import SwiftUI

struct CommunityPostRow: View {
    let post: CommunityPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.text)
                .font(.body)

            HStack(spacing: 12) {
                Text(timeAgoString(from: post.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(.vertical, 6)
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let m = Int(interval / 60)
            return "\(m)m ago"
        } else if interval < 86_400 {
            let h = Int(interval / 3600)
            return "\(h)h ago"
        } else {
            let d = Int(interval / 86_400)
            return "\(d)d ago"
        }
    }
}
