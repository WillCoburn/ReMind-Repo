import SwiftUI

struct CommunityComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Sheet background
                Color.palettePewter
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {

                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.communityBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.paletteIvory, lineWidth: 3) // visible border
                                )
                                .compositingGroup()
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.black)
                        .focused($isTextEditorFocused)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Share something you found uplifting or meaningful...")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                            }
                        }

                    Text("Community posts expire automatically after 3 days.\nAnything rude or offensive will result in a ban.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding()
            }
            .onAppear {
                // Ask for focus as soon as this view appears
                isTextEditorFocused = true
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.paletteIvory)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await handleSubmit() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.paletteIvory)
                            } else {
                                Text("Post")
                                    .font(.headline)
                                    .foregroundColor(.paletteIvory)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.paletteTealGreen)
                        )
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .opacity((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting) ? 0.5 : 1.0)
                }
            }

            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) { errorMessage = nil }
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
        }
    }

    private func handleSubmit() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await CommunityAPI.shared.createPost(text: trimmed)
            dismiss()
        } catch {
            let nsError = error as NSError
            print("🔥 createCommunityPost error:", nsError, nsError.userInfo)
            errorMessage = nsError.localizedDescription
        }
    }
}
