import SwiftUI

struct RightPanelPlaceholderDetailView: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(tint.opacity(0.18))
                .frame(height: 180)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundColor(tint)
                )
                .padding(.top, 8)

            Text(title)
                .font(.largeTitle.bold())

            Text("Placeholder space for future \(title.lowercased()) details. Tap tiles on the main grid to preview different areas for upcoming settings and stats.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
