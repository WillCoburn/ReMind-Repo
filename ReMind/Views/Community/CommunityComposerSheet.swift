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
                Color.white
                    .ignoresSafeArea()

                Color.figmaBlue.opacity(0.04)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                )
                                .compositingGroup()
                        )
                        .foregroundColor(.primary)
                        .focused($isTextEditorFocused)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Share something you found uplifting or meaningful...")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                            }
                        }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(.gray)

                        Text("Community posts expire automatically after 7 days.\nAnything rude or offensive will result in a ban.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                    .cornerRadius(10)

                    Spacer()
                    
                    
                    HStack {
                        Spacer()

                        Button {
                            Task { await handleSubmit() }
                        } label: {
                            Text("Post")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.figmaBlue)
                                )
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                        .opacity((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting) ? 0.5 : 1.0)
                    }
                }
                .padding()
            }
            .onAppear {
                // Ask for focus as soon as this view appears
                isTextEditorFocused = true
            }
            .navigationTitle("Community Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.figmaBlue)
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
