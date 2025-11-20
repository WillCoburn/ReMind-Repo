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
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    reminderCountTile
                    sentRemindersTile
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
            Color(hex: "#65cfc1")
                .ignoresSafeArea()
        )
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
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


