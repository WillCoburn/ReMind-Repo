// ======================
// File: Views/MainView.swift
// ======================
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appVM: AppViewModel

    @State private var input: String = ""
    @State private var showExportSheet = false
    @State private var showSuccessMessage = false

    // Prefer the VM's counter so we don't need to fetch the whole list
    private var count: Int { appVM.submissionsCount }
    private let goal: Int = 10

    var body: some View {
        content
            // Force a fresh MainView when the user changes (prevents sticky local @State)
            .id(appVM.profile?.uid ?? "anon")
            .onChange(of: appVM.profile?.uid) { _ in
                input = ""
                showSuccessMessage = false
            }
            // Put the envelope in the nav bar (single instance, owned by this screen)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showExportSheet = true } label: {
                        Image(systemName: "envelope")
                            .font(.title3.weight(.semibold))
                            .accessibilityLabel("Email me a PDF of my entries")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportSheet()
            }
    }

    private var content: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 32)

            // Success message ABOVE the input bubble
            if showSuccessMessage {
                Text("✅ Successfully stored!")
                    .font(.footnote)
                    .foregroundColor(.green)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.3), value: showSuccessMessage)
            }

            // Input row
            HStack(alignment: .center, spacing: 12) {
                TextField("Type a moment of clarity…", text: $input, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )

                Button {
                    Task { await sendAffirmation() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)

            // Show the progress/hint ONLY until the goal is reached
            if count < goal {
                HintBadge(count: count, goal: goal)
                    // ensure it resets entirely when a different user logs in
                    .id("hint-\(appVM.profile?.uid ?? "anon")")
                    .padding(.horizontal)
            }

            Spacer(minLength: 16)
        }
    }

    // MARK: - Actions
    private func sendAffirmation() async {
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
