// =====================================
// File: Views/Settings/UserSettingsPanel.swift
// =====================================
import SwiftUI
import PhotosUI

struct UserSettingsPanel: View {
    @Binding var remindersPerDay: Double
    @Binding var tzIdentifier: String
    @Binding var quietStartHour: Double
    @Binding var quietEndHour: Double
    @Binding var bgImageBase64: String

    var onClose: () -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var loadError: String?

    // Updated range constants
    private let minReminders: Double = 0.1
    private let maxReminders: Double = 5.0
    private let stepReminders: Double = 0.1

    private let usTimeZones: [String] = {
        var ids = TimeZone.knownTimeZoneIdentifiers.filter {
            $0.hasPrefix("US/") || $0.hasPrefix("America/")
        }
        let preferred = [
            "America/New_York", "America/Chicago", "America/Denver", "America/Phoenix",
            "America/Los_Angeles", "America/Anchorage", "America/Adak", "Pacific/Honolulu"
        ]
        let preferredSet = Set(preferred)
        let others = ids.filter { !preferredSet.contains($0) }.sorted()
        ids = preferred + others
        var seen = Set<String>(); return ids.filter { seen.insert($0).inserted }
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Updated: 0.1–5.0/day slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Reminders per day")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(remindersDisplay(remindersPerDay)) / day")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $remindersPerDay,
                               in: minReminders...maxReminders,
                               step: stepReminders)

                        Text("Choose how many reminders to receive each day (in tenths). For example, 0.1 = about once every 10 days.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Time zone picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Zone")
                            .font(.subheadline.weight(.semibold))

                        Picker("Time Zone", selection: $tzIdentifier) {
                            ForEach(usTimeZones, id: \.self) { id in
                                Text(prettyTimeZone(id)).tag(id)
                            }
                        }
                        .pickerStyle(.wheel)

                        Text("Used for scheduling sends at the right local time.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }

                    Divider()

                    // Send window
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Send Window")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(hourLabel(quietStartHour)) – \(hourLabel(quietEndHour))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            HStack {
                                Text("Earliest")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Slider(value: Binding(
                                    get: { quietStartHour },
                                    set: { quietStartHour = min($0, quietEndHour) }
                                ), in: 0...23, step: 1)
                                Text(hourLabel(quietStartHour))
                                    .font(.footnote.monospaced())
                                    .frame(width: 44)
                            }
                            HStack {
                                Text("Latest")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Slider(value: Binding(
                                    get: { quietEndHour },
                                    set: { quietEndHour = max($0, quietStartHour) }
                                ), in: 0...23, step: 1)
                                Text(hourLabel(quietEndHour))
                                    .font(.footnote.monospaced())
                                    .frame(width: 44)
                            }
                        }

                        Text("Reminders will be scheduled only between these hours.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Background selector (unchanged)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 12) {
                            if let preview = previewImage() {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(.secondary.opacity(0.3), lineWidth: 1))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.secondary.opacity(0.08))
                                    Image(systemName: "photo")
                                        .imageScale(.large)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 72, height: 72)
                            }

                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("Choose Photo", systemImage: "photo.on.rectangle")
                            }
                            .onChange(of: photoItem) { newItem in
                                Task { await importPhoto(newItem) }
                            }

                            if !bgImageBase64.isEmpty {
                                Button(role: .destructive) {
                                    bgImageBase64 = ""
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }

                        if let loadError {
                            Text(loadError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Text("Pick a photo to personalize your app background.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)
                }
                .padding(16)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20, y: 8)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(.clear)
        .padding(.top, 8)
    }

    // MARK: Helpers

    private func remindersDisplay(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func hourLabel(_ value: Double) -> String {
        let h = Int(round(value)) % 24
        let ampm = h >= 12 ? "PM" : "AM"
        let hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(hour12)\u{00A0}\(ampm)"
    }

    private func prettyTimeZone(_ id: String) -> String {
        if let tz = TimeZone(identifier: id) {
            let seconds = tz.secondsFromGMT()
            let hours = seconds / 3600
            let minutes = abs((seconds % 3600) / 60)
            let sign = hours >= 0 ? "+" : "-"
            return "GMT\(sign)\(abs(hours)):\(String(format: "%02d", minutes)) – \(id)"
        }
        return id
    }

    private func previewImage() -> UIImage? {
        guard !bgImageBase64.isEmpty, let data = Data(base64Encoded: bgImageBase64) else { return nil }
        return UIImage(data: data)
    }

    private func importPhoto(_ item: PhotosPickerItem?) async {
        loadError = nil
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if let img = UIImage(data: data) {
                    let resized = img.resized(maxDimension: 2000)
                    if let jpeg = resized.jpegData(compressionQuality: 0.85) {
                        bgImageBase64 = jpeg.base64EncodedString()
                    } else {
                        bgImageBase64 = data.base64EncodedString()
                    }
                } else {
                    bgImageBase64 = data.base64EncodedString()
                }
            }
        } catch {
            loadError = "Couldn't load photo. Please try a different image."
        }
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
