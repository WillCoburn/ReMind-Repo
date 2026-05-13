// ============================
// File: Views/Sheets/ExportSheet.swift
// ============================
import SwiftUI
import FirebaseAuth

@MainActor
struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel
    @ObservedObject private var revenueCat: RevenueCatManager = .shared

    @State private var isExporting = false
    @State private var link: URL? = nil
    @State private var error: String? = nil
    @State private var showToast = false
    @State private var animateIllustration = false

    private let exporter: ExportService = FirebaseExportService()

    var body: some View {
        let _ = revenueCat.entitlementActive
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 244/255, green: 248/255, blue: 255/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let isCompact = proxy.size.height < 650

                VStack(spacing: isCompact ? 18 : 24) {
                    Spacer(minLength: isCompact ? 12 : 28)

                    ExportPDFIllustration(
                        isExporting: isExporting,
                        didExport: link != nil,
                        animate: animateIllustration
                    )
                    .frame(height: isCompact ? 190 : 240)
                    .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(titleText)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Color.black.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if let error {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Compile your entries into a clean PDF and receive a text with the link.")
                                .font(.subheadline)
                                .foregroundColor(Color.black.opacity(0.58))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let link {
                            HStack(spacing: 10) {
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
                    .padding(.horizontal, 30)
                    .frame(maxWidth: 430)

                    Spacer(minLength: 12)

                    VStack(spacing: 12) {
                        Button {
                            print("🧭 Export button tapped")
                            Task { await runExport() }
                        } label: {
                            Group {
                                if isExporting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text(link == nil ? "Export" : "Export again")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .foregroundColor(.white)
                        .background(isExporting ? Color.figmaBlue.opacity(0.6) : Color.figmaBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.figmaBlue.opacity(isExporting ? 0 : 0.22), radius: 16, x: 0, y: 8)
                        .disabled(isExporting)

                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .font(.headline)
                        }
                        .foregroundColor(Color.black.opacity(0.62))
                        .background(Color.white.opacity(0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 16, 24))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
        .onAppear { restartIllustration() }
        .dynamicTypeSize(.xSmall ... .xxLarge)
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

    private var titleText: String {
        if isExporting { return "Building your PDF..." }
        if link != nil { return "Export ready" }
        return "Full PDF export"
    }

    private func restartIllustration() {
        animateIllustration = false
        DispatchQueue.main.async {
            animateIllustration = true
        }
    }
}

private struct ExportPDFIllustration: View {
    let isExporting: Bool
    let didExport: Bool
    let animate: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.figmaBlue.opacity(0.08))
                .frame(width: 210, height: 210)
                .scaleEffect(animate ? 1.04 : 0.96)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animate)

            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .frame(width: 112, height: 146)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 9) {
                            Capsule()
                                .fill(Color.figmaBlue.opacity(0.26))
                                .frame(width: 54, height: 7)
                            Capsule()
                                .fill(Color.figmaBlue.opacity(0.14))
                                .frame(width: 78, height: 6)
                            Capsule()
                                .fill(Color.figmaBlue.opacity(0.11))
                                .frame(width: 66, height: 6)
                        }
                        .padding(18)
                    }
                    .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 7)
                    .rotationEffect(.degrees(Double(index - 1) * (animate ? 5.5 : 3.5)))
                    .offset(
                        x: CGFloat(index - 1) * 23,
                        y: CGFloat(index) * 5 + (animate ? CGFloat(index - 1) * -3 : 0)
                    )
                    .animation(
                        .easeInOut(duration: 2.1)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.13),
                        value: animate
                    )
            }

            if didExport {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.figmaBlue)
                    .background(Circle().fill(Color.white))
                    .offset(x: 68, y: -62)
                    .transition(.scale.combined(with: .opacity))
            } else if isExporting {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.figmaBlue)
                    .offset(x: 70, y: -58)
                    .scaleEffect(animate ? 1.06 : 0.92)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animate)
            }
        }
        .frame(maxWidth: .infinity)
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
