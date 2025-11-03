// ======================
// File: Views/MainView.swift
// ======================
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appVM: AppViewModel

    @State private var input: String = ""
    @State private var showExportSheet = false
    @State private var showSuccessMessage = false

    // Alert plumbing (for the “need 10 entries” message)
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // Goal for unlocking actions
    private let goal: Int = 10

    var body: some View {
        // Snapshot values (avoid EnvironmentObject wrapper diagnostics)
        let count = appVM.entries.count

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
            // iOS 15+ safe placement; group both icons
            ToolbarItemGroup(placement: .navigationBarTrailing) {

                // 📩 Export — always visible; “locked” until goal
                Button {
                    if count < goal {
                        presentLockedAlert(feature: "Export PDF")
                    } else {
                        showExportSheet = true
                    }
                } label: {
                    Image(systemName: "envelope.fill")
                        .font(.title3.weight(.semibold))
                }
                .opacity(count < goal ? 0.35 : 1.0)
                .accessibilityLabel("Email me a PDF of my entries")
                .accessibilityHint(
                    count < goal
                    ? "Unlocks after you have at least \(goal) entries."
                    : "Opens export options."
                )

                // ⚡ Send now — always visible; “locked” until goal
                Button {
                    Task {
                        if count < goal {
                            presentLockedAlert(feature: "Send One Now")
                            return
                        }
                        let ok = await appVM.sendOneNow()
                        if ok { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
                    }
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.title3.weight(.semibold))
                }
                .opacity(count < goal ? 0.35 : 1.0)
                .accessibilityLabel("Send one now")
                .accessibilityHint(
                    count < goal
                    ? "Unlocks after you have at least \(goal) entries."
                    : "Sends a reminder immediately."
                )
            }
        }
        .sheet(isPresented: $showExportSheet) { ExportSheet() }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(alertMessage) }
    }

    // MARK: - Actions
    private func sendEntry() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        await appVM.submit(text: text)
        input = ""

        withAnimation(.easeInOut(duration: 0.2)) { showSuccessMessage = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) { showSuccessMessage = false }
        }
    }

    // MARK: - Alert helper
    private func presentLockedAlert(feature: String) {
        alertTitle = "Keep going!"
        alertMessage = "You need at least \(goal) entries to use “\(feature)”. Add more entries to unlock this feature."
        showAlert = true
    }
}
