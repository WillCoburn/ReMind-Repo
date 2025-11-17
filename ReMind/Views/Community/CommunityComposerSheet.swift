import SwiftUI

struct CommunityComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Share a reminder with the community.")
                    .font(.headline)

                TextEditor(text: $text)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )

                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await handleSubmit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Post")
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK", role: .cancel) { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
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
            errorMessage = error.localizedDescription
        }
    }
}
