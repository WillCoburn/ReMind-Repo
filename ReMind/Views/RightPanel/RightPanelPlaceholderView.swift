import SwiftUI

struct RightPanelPlaceholderView: View {
    @EnvironmentObject private var appVM: AppViewModel

    @AppStorage("remindersPerWeek") private var remindersPerWeek: Double = 7.0 // 1...20
    @AppStorage("tzIdentifier")    private var tzIdentifier: String = TimeZone.current.identifier
    @AppStorage("quietStartHour")  private var quietStartHour: Double = 9     // 0...23
    @AppStorage("quietEndHour")    private var quietEndHour: Double = 22      // 0...23
    @AppStorage("bgImageBase64")   private var bgImageBase64: String = ""

    @State private var pendingSaveWorkItem: DispatchWorkItem?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LazyVGrid(
                    columns: Array(repeating: .init(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    sentRemindersTile
                    streakTile
                    reminderCountTile
                }
                .padding(.horizontal)

                settingsCard
                    .padding(.horizontal)
            }
            .padding(.vertical, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Stats & Settings")
                    .font(.headline)
            }
        }
        .background(
            Color.momGreen.ignoresSafeArea()
        )
        .foregroundColor(.palettePewter)
    }

    private var settingsCard: some View {
        UserSettingsForm(
            remindersPerWeek: $remindersPerWeek,
            tzIdentifier: $tzIdentifier,
            quietStartHour: $quietStartHour,
            quietEndHour: $quietEndHour,
            bgImageBase64: $bgImageBase64,
            onSettingsChanged: persistSettingsDebounced
        )
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.paletteIvory.opacity(0.9))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.paletteTurquoise.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }

    private func persistSettingsDebounced() {
        pendingSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            UserSettingsSync.pushAndApply { err in
                print("pushAndApply (right panel) ->", err?.localizedDescription ?? "OK")
            }
        }

        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }
}

struct RightPanelPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        RightPanelPlaceholderView()
            .environmentObject(AppViewModel())
    }
}

private extension RightPanelPlaceholderView {
    
    // MARK: - SAVED TILE
    var reminderCountTile: some View {
        let tint: Color = .palettePewter
        
        return VStack(spacing: 8) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.paletteIvory)

            Text("Saved")
                .font(.headline)
                .foregroundColor(.paletteIvory)

            Text("\(appVM.entries.count)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.paletteIvory)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.blue.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .frame(height: 130) // consistent height for all three tiles
    }
    
    // MARK: - SENT TILE
    var sentRemindersTile: some View {
        let tint: Color = .palettePewter
        
        return VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.paletteIvory)

            Text("Sent")
                .font(.headline)
                .foregroundColor(.paletteIvory)

            Text("\(appVM.sentEntriesCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.paletteIvory)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.blue.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .frame(height: 130)
    }
    
    // MARK: - STREAK TILE
    var streakTile: some View {
        let tint: Color = .palettePewter

        return VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.paletteIvory)

            Text("Streaks")
                .font(.headline)
                .foregroundColor(.paletteIvory)

            Text("\(appVM.streakCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.paletteIvory)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .frame(height: 130)
    }
}
