import SwiftUI

struct RightPanelPlaceholderView: View {
    @EnvironmentObject private var appVM: AppViewModel

    private let tiles: [PlaceholderTile] = [
        .init(title: "Wins", subtitle: "Celebrate", icon: "star.fill", tint: .yellow, destination: WinsPlaceholderView()),
        .init(title: "Habits", subtitle: "Daily steps", icon: "flame.fill", tint: .red, destination: HabitsPlaceholderView()),
        .init(title: "Energy", subtitle: "Check balance", icon: "bolt.fill", tint: .teal, destination: EnergyPlaceholderView()),
        .init(title: "Mood", subtitle: "Track feelings", icon: "face.smiling", tint: .mint, destination: MoodPlaceholderView()),
        .init(title: "Sleep", subtitle: "Rest well", icon: "bed.double.fill", tint: .indigo, destination: SleepPlaceholderView()),
        .init(title: "Activity", subtitle: "Move more", icon: "figure.walk", tint: .green, destination: ActivityPlaceholderView()),
        .init(title: "Notes", subtitle: "Jot ideas", icon: "square.and.pencil", tint: .purple, destination: NotesPlaceholderView()),
        .init(title: "Archive", subtitle: "Keep records", icon: "tray.full.fill", tint: .pink, destination: ArchivePlaceholderView())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 16), count: 2), spacing: 16) {
                reminderCountTile
                sentRemindersTile

                ForEach(tiles) { tile in
                    NavigationLink(destination: tile.destination) {
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
            .environmentObject(AppViewModel())
    }
}


private struct PlaceholderTile: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let destination: AnyView

    init<Destination: View>(title: String, subtitle: String, icon: String, tint: Color, destination: Destination) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.destination = AnyView(destination)
    }
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

private extension RightPanelPlaceholderView {
    var reminderCountTile: some View {
        let tint: Color = .orange

        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("ReMinders saved")
                .font(.headline)
                .foregroundColor(.primary)

            Text("\(appVM.entries.count)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Total so far")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
    var sentRemindersTile: some View {
        let tint: Color = .blue

        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(tint)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("ReMinders sent")
                .font(.headline)
                .foregroundColor(.primary)

            Text("\(appVM.sentEntriesCount)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Delivered via auto + instant")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
    
}


