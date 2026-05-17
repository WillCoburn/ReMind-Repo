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

                ScrollView(showsIndicators: false) {
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
                                Text("Compile all of your entries into a chronological PDF to view your thoughts over time.")
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
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.82)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 52)
                            }
                            .foregroundColor(.white)
                            .background(isExporting ? Color.figmaBlue.opacity(0.6) : Color.figmaBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.figmaBlue.opacity(isExporting ? 0 : 0.22), radius: 16, x: 0, y: 8)
                            .disabled(isExporting)

                            Button(action: { dismiss() }) {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 52)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
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
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.figmaBlue)
        .onAppear { restartIllustration() }
        .brainMailDynamicTypeRange()
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
            let url = try await exporter.exportAndSend(entries: appVM.activeEntries)
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
    @State private var cycleStart = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !animate)) { timeline in
            let elapsed = animate ? timeline.date.timeIntervalSince(cycleStart) : 0
            let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: 4.2) / 4.2)

            ExportPDFStackAnimation(
                phase: phase,
                isExporting: isExporting,
                didExport: didExport
            )
        }
        .onAppear {
            cycleStart = Date()
        }
        .onChange(of: animate) { isAnimating in
            if isAnimating {
                cycleStart = Date()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExportPDFStackAnimation: View {
    let phase: CGFloat
    let isExporting: Bool
    let didExport: Bool

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let availableHeight = max(proxy.size.height, 1)
            let pageWidth = min(max(availableWidth * 0.34, 96), 118)
            let pageHeight = pageWidth * 1.30
            let circleSize = min(max(pageWidth * 1.92, 190), min(availableWidth * 0.84, availableHeight * 0.96))
            let fan = fanProgress(for: phase)
            let glowPulse = 1 + sin(Double(phase) * Double.pi * 2) * 0.018

            ZStack {
                Circle()
                    .fill(Color.figmaBlue.opacity(0.08))
                    .frame(width: circleSize, height: circleSize)
                    .scaleEffect(glowPulse + Double(fan) * 0.018)

                ForEach(0..<3, id: \.self) { index in
                    let side = CGFloat(index - 1)
                    let drift = CGFloat(sin(Double(phase) * Double.pi * 2 + Double(index) * 0.78))
                    let rotation = side * (3.0 + fan * 8.0) + drift * 0.65
                    let offsetX = side * (10 + fan * 31) + drift * 2.2
                    let offsetY = CGFloat(index) * 5 - (index == 1 ? fan * 8 : 0) + drift * 3
                    let pageScale = 1 + (index == 1 ? fan * 0.018 : -fan * 0.006)

                    ExportPDFPage(width: pageWidth, height: pageHeight, index: index)
                        .scaleEffect(pageScale)
                        .rotationEffect(.degrees(Double(rotation)))
                        .offset(x: offsetX, y: offsetY)
                        .zIndex(index == 1 ? 3 : Double(index))
                }

                if didExport {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.figmaBlue)
                        .background(Circle().fill(Color.white))
                        .offset(x: pageWidth * 0.64, y: -pageHeight * 0.43)
                        .transition(.scale.combined(with: .opacity))
                } else if isExporting {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.figmaBlue)
                        .offset(x: pageWidth * 0.66, y: -pageHeight * 0.40)
                        .scaleEffect(0.94 + fan * 0.10)
                }
            }
            .frame(width: availableWidth, height: availableHeight)
        }
    }

    private func fanProgress(for phase: CGFloat) -> CGFloat {
        if phase < 0.10 { return 0 }
        if phase < 0.36 { return easeInOut((phase - 0.10) / 0.26) }
        if phase < 0.66 { return 1 }
        if phase < 0.90 { return 1 - easeInOut((phase - 0.66) / 0.24) }
        return 0
    }

    private func easeInOut(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}

private struct ExportPDFPage: View {
    let width: CGFloat
    let height: CGFloat
    let index: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.94))
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 9) {
                    Capsule()
                        .fill(Color.figmaBlue.opacity(0.26))
                        .frame(width: width * 0.48, height: 7)
                    Capsule()
                        .fill(Color.figmaBlue.opacity(0.14))
                        .frame(width: width * 0.70, height: 6)
                    Capsule()
                        .fill(Color.figmaBlue.opacity(0.11))
                        .frame(width: width * 0.58, height: 6)
                    Capsule()
                        .fill(Color(red: 222/255, green: 174/255, blue: 202/255).opacity(0.20))
                        .frame(width: width * (index == 1 ? 0.44 : 0.36), height: 6)
                }
                .padding(18)
            }
            .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 7)
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
