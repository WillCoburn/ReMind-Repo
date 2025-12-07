// ============================
// File: Views/Sheets/ExportSheet.swift
// ============================
import SwiftUI
import FirebaseAuth

@MainActor
struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel

    @State private var isExporting = false
    @State private var link: URL? = nil
    @State private var error: String? = nil
    @State private var showToast = false

    private let exporter: ExportService = FirebaseExportService()

    var body: some View {
        NavigationView {
            ZStack {
                // Base → white, then soft blue overlay
                Color.white
                Color.figmaBlue.opacity(0.08)

                VStack {
                    Spacer()

                    // --- Centered icon + message block ---
                    VStack(spacing: 24) {
                        if isExporting {
                            ProgressView("Generating PDF…")
                                .progressViewStyle(.circular)
                        } else {
                            Image("pdficon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 240, height: 240)   // Larger icon
                        }

                        if let error {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        } else {
                            Text("Compile your entries into a PDF and receive a text with the link.")
                                .font(.subheadline)
                                .foregroundColor(Color.black.opacity(0.65))   // More visible gray
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        if let link {
                            VStack(spacing: 10) {
                                Button("Copy link") {
                                    UIPasteboard.general.string = link.absoluteString
                                }
                                .buttonStyle(.bordered)

                                Link("Open link", destination: link)
                                    .buttonStyle(.bordered)
                            }
                            .padding(.top, 4)
                        }
                    }

                    Spacer()

                    // --- Bottom buttons ---
                    VStack(spacing: 12) {
                        Button {
                            print("🧭 Export button tapped")
                            Task { await runExport() }
                        } label: {
                            Text("Export")
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .background(isExporting ? Color.figmaBlue.opacity(0.6) : Color.figmaBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .disabled(isExporting)

                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .background(Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Export")
                        .font(.headline)
                        .foregroundColor(.black)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .toast(isPresented: $showToast) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Text sent!")
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func runExport() async {
        print("🚀 Starting runExport()")
        error = nil
        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await exporter.exportAndSend(entries: appVM.entries)
            print("✅ exportAndSend returned:", url)
            self.link = url
            self.showToast = true
        } catch {
            print("❌ Export failed:", error.localizedDescription)
            self.error = error.localizedDescription
        }
    }
}


// Simple toast view modifier
fileprivate struct ToastOverlay<ToastView: View>: ViewModifier {
    @Binding var isPresented: Bool
    let overlay: () -> ToastView

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                VStack {
                    overlay()
                    Spacer().frame(height: 0)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.25), value: isPresented)
            }
        }
    }
}

fileprivate extension View {
    func toast<ToastView: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder _ overlay: @escaping () -> ToastView
    ) -> some View {
        modifier(ToastOverlay(isPresented: isPresented, overlay: overlay))
    }
}
