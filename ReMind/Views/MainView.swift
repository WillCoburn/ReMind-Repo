// ======================
// File: Views/MainView.swift
// ======================
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appVM: AppViewModel

    @State private var input: String = ""
    @State private var showExportSheet = false
    @State private var showSuccessMessage = false

    // Current number of entries
    private var count: Int { appVM.entries.count }   

    // When to show the ⚡ button
    private let goal: Int = 10

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 32)

            // Success toast above input
            if showSuccessMessage {
                Text("✅ Successfully stored!")
                    .font(.footnote)
                    .foregroundColor(.green)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.3), value: showSuccessMessage)
            }

            // Input row
            HStack(alignment: .center, spacing: 12) {
                TextField("Type an entry…", text: $input, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )

                Button {
                    Task { await sendEntry() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Submit entry")
            }
            .padding(.horizontal)

            // Progress / hint badge
            HintBadge(count: count, goal: goal)
                .padding(.horizontal)

            Spacer(minLength: 16)
        }
        .navigationTitle("ReMind")
        .toolbar {
            // 📩 Export (always visible)
            ToolbarItem(placement: .topBarTrailing) {
                Button { showExportSheet = true } label: {
                    Image(systemName: "envelope.fill")
                        .font(.title3.weight(.semibold))
                }
                .accessibilityLabel("Email me a PDF of my entries")
            }

            // ⚡ Send one now (include the whole ToolbarItem conditionally)
            if count >= goal {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let ok = await appVM.sendOneNow()
                            if ok { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
                        }
                    } label: {
                        Image(systemName: "bolt.fill")
                            .font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel("Send one now")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            // Replace with your actual export UI if different
            ExportSheet()
        }
    }

    // MARK: - Actions
    private func sendEntry() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        await appVM.submit(text: text)
        input = ""

        withAnimation(.easeInOut(duration: 0.2)) {
            showSuccessMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSuccessMessage = false
            }
        }
    }
}
