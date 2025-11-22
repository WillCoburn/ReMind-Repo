// =========================================================
// File: Views/Settings/Sections/BackgroundPickerSection.swift
// =========================================================
import SwiftUI
import PhotosUI

struct BackgroundPickerSection: View {
    @Binding var photoItem: PhotosPickerItem?
    @Binding var bgImageBase64: String
    @Binding var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Background")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                if let preview = SettingsHelpers.previewImage(fromBase64: bgImageBase64) {
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

        }
    }

    private func importPhoto(_ item: PhotosPickerItem?) async {
        loadError = nil
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if let img = UIImage(data: data) {
                    let resized = img.remind_resized(maxDimension: 2000)
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
