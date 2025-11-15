// ==================================================
// File: Views/Settings/Sections/TimeZoneSection.swift
// ==================================================
import SwiftUI

struct TimeZoneSection: View {
    @Binding var tzIdentifier: String
    var usTimeZones: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Zone")
                .font(.subheadline.weight(.semibold))

            Picker("Time Zone", selection: $tzIdentifier) {
                ForEach(usTimeZones, id: \.self) { id in
                    Text(SettingsHelpers.prettyTimeZone(id)).tag(id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Used for scheduling sends at the right local time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
}
