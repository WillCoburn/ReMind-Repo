import SwiftUI

struct RightPanelPlaceholderView: View {
    
    private let tiles: [PlaceholderTile] = [
        .init(title: "Focus", subtitle: "Stay on track", icon: "target", tint: .orange),
        .init(title: "Trends", subtitle: "See patterns", icon: "chart.line.uptrend.xyaxis", tint: .blue),
        .init(title: "Wins", subtitle: "Celebrate", icon: "star.fill", tint: .yellow),
        .init(title: "Habits", subtitle: "Daily steps", icon: "flame.fill", tint: .red),
        .init(title: "Energy", subtitle: "Check balance", icon: "bolt.fill", tint: .teal),
        .init(title: "Mood", subtitle: "Track feelings", icon: "face.smiling", tint: .mint),
        .init(title: "Sleep", subtitle: "Rest well", icon: "bed.double.fill", tint: .indigo),
        .init(title: "Activity", subtitle: "Move more", icon: "figure.walk", tint: .green),
        .init(title: "Notes", subtitle: "Jot ideas", icon: "square.and.pencil", tint: .purple),
        .init(title: "Archive", subtitle: "Keep records", icon: "tray.full.fill", tint: .pink)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(tiles) { tile in
                    NavigationLink {
                        PlaceholderDetailView(tile: tile)
                    } label: {
                        PlaceholderTileView(tile: tile)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        
        .navigationTitle("Right Panel")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            Color(hex: "#65cfc1")
                .ignoresSafeArea()
        )
    }
}

struct RightPanelPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        RightPanelPlaceholderView()
    }
}


private struct PlaceholderTile: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
}

private struct PlaceholderTileView: View {
    let tile: PlaceholderTile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: tile.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(tile.tint)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(tile.title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(tile.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tile.tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tile.tint.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct PlaceholderDetailView: View {
    let tile: PlaceholderTile

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(tile.tint.opacity(0.18))
                .frame(height: 180)
                .overlay(
                    Image(systemName: tile.icon)
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundColor(tile.tint)
                )
                .padding(.top, 8)

            Text(tile.title)
                .font(.largeTitle.bold())

            Text("Placeholder space for future \(tile.title.lowercased()) details. Tap tiles on the main grid to preview different areas for upcoming settings and stats.")
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
        .navigationTitle(tile.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

