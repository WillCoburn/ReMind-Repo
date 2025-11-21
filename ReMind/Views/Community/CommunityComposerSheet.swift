import SwiftUI

struct CommunityComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Share something you found uplifting or meaningful.")
                    .font(.headline)
                    .foregroundColor(.white)

                TextEditor(text: $text)
                    .frame(minHeight: 160)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.communityBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.communityBackground, lineWidth: 3)
                            )
                            .compositingGroup()                      // ⬅️ allows overlay to render fully
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))   // ⬅️ prevents clipping INSIDE the scrollview
                    .foregroundColor(.black)
                    .focused($isTextEditorFocused)


                Text("Community posts expire automatically after 3 days. Anything rude or offensive will result in a ban.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()
            }
            .padding()
            .onAppear {
                // Ask for focus as soon as this view appears
                isTextEditorFocused = true
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.paletteTurquoise)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await handleSubmit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.paletteTurquoise)
                        } else {
                            Text("Post")
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .foregroundColor(.paletteTurquoise)
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
        .background(Color.paletteTurquoise.ignoresSafeArea())
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
