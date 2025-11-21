import SwiftUI

struct CommunityComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Share something you found uplifting or meaningful.")
                    .font(.headline)
                    .foregroundColor(.white)

                TextEditor(text: $text)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.paletteTealGreen.opacity(0.12))
                    )
                    .foregroundColor(.palettePewter)
                
                Text("Community posts expire automatically after 3 days. Anything rude or offensive will result in a ban.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
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
