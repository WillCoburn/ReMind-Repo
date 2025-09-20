// ======================
// File: Views/MainView.swift
// ======================
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appVM: AppViewModel

    @State private var input: String = ""
    @State private var showExportSheet = false
    @State private var showSuccessMessage = false

    // If you keep an array of affirmations:
    private var count: Int { appVM.affirmations.count }
    // If you switched to a counter instead, replace the line above with:
    // private var count: Int { appVM.submissionsCount }

    private let goal: Int = 10

    var body: some View {
        NavigationView {
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
                        Task { await sendAffirmation() }   // <- no name clash with VM method
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)

                // Progress / hint badge
                HintBadge(count: count, goal: goal)
                    .padding(.horizontal)

                Spacer(minLength: 16)
            }
            .navigationTitle("ReMind")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showExportSheet = true } label: {
                        Image(systemName: "envelope.fill")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportSheet()   // placeholder
            }
        }
    }

    // MARK: - Actions
    /// Renamed from `submit()` to avoid any accidental collision with `AppViewModel.submit(...)`
    private func sendAffirmation() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        await appVM.submit(text: text)   // <- call the environment object value (no `$`)
        input = ""

        // Flash the success message above the input bubble
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
