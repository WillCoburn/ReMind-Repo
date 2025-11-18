import SwiftUI

struct CommunityPostRow: View {
    let post: CommunityPost
    
    var onLike: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(post.text)
                .font(.body)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                Label(timeAgoString(from: post.createdAt), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                

            }
            
            HStack(spacing: 12) {
                Spacer()
                
                Button {
                    onLike?()
                } label: {
                    Label("\(post.likeCount)", systemImage: "arrow.up.square.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                
                Button {
                    onReport?()
                } label: {
                    Label("\(post.reportCount)", systemImage: "flag.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
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
