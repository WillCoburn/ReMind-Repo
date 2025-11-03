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
            VStack(spacing: 16) {
                if isExporting {
                    ProgressView("Generating PDF…")
                        .progressViewStyle(.circular)
                        .padding(.top, 8)
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 40, weight: .semibold))
                        .padding(.top, 8)
                }

                if let error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Compile your entries into a PDF and receive a text with the link.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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

                Spacer()

                Button {
                    print("🧭 Export button tapped") // ✅ Step 3: start log
                    Task {
                        await runExport()
                    }
                } label: {
                    Text("Export & Text Me")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)

                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
            }
            .padding()
            .navigationTitle("Export")
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
        print("🚀 Starting runExport()") // ✅ New log
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
