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
        .navigationTitle("Stats & Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            Color.paletteTealGreen
                .ignoresSafeArea()
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
        
        return VStack(spacing: 12) {
            
            // Centered icon
            Image(systemName: "tray.full.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.paletteIvory)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Centered "Saved" text
            Text("Saved")
                .font(.headline)
                .foregroundColor(.paletteIvory)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Centered big number
            Text("\(appVM.entries.count)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.paletteIvory)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.palettePewter.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
    
    
    // MARK: - SENT TILE
    var sentRemindersTile: some View {
        let tint: Color = .palettePewter
        
        return VStack(spacing: 12) {
            
            // Centered icon
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.paletteIvory)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Centered "Sent" text
            Text("Sent")
                .font(.headline)
                .foregroundColor(.paletteIvory)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Centered big number
            Text("\(appVM.sentEntriesCount)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.paletteIvory)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.palettePewter.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
    
    // MARK: - STREAK TILE
    var streakTile: some View {
        let tint: Color = .palettePewter

        return VStack(spacing: 12) {

            // Centered icon
            Image(systemName: "flame.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.paletteIvory)
                .frame(maxWidth: .infinity, alignment: .center)

            // Centered "Streaks" text
            Text("Streaks")
                .font(.headline)
                .foregroundColor(.paletteIvory)
                .frame(maxWidth: .infinity, alignment: .center)

            // Centered big number
            Text("\(appVM.streakCount)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.paletteIvory)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.palettePewter.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}
