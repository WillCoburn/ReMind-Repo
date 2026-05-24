import SwiftUI

struct CommunityComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        ZStack {
            BrainMailComposeSheetBackground()

            VStack(alignment: .leading, spacing: 0) {
                BrainMailComposeSheetHeader(
                    title: "Community note",
                    subtitle: "Share something uplifting or meaningful with others."
                )
                .padding(.bottom, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 24 : 22)

                BrainMailComposeInputBox(
                    text: $text,
                    placeholder: "Share something you found uplifting or meaningful...",
                    minHeight: 160,
                    accessibilityIdentifier: "community.compose.textEditor",
                    focus: $isTextEditorFocused
                )
                .padding(.bottom, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 18 : 16)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.gray)

                    Text("Community posts expire automatically after 7 days.\nAnything rude or offensive will result in a ban.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .cornerRadius(10)

                Spacer(minLength: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 24 : 20)

                HStack(alignment: .center, spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.figmaBlue)
                        .frame(minHeight: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 50 : 44)
                        .buttonStyle(.plain)

                    Spacer(minLength: 12)

                    Button {
                        Task { await handleSubmit() }
                    } label: {
                        BrainMailComposePrimaryButtonLabel(
                            title: "Post",
                            loadingTitle: "Posting…",
                            isLoading: isSubmitting,
                            isDisabled: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting
                        )
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 28 : 24)
            .padding(.top, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 48 : 44)
            .padding(.bottom, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 22 : 18)
        }
        .presentationDragIndicator(.visible)
        .task {
            await Task.yield()
            isTextEditorFocused = true
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
        .brainMailDynamicTypeRange()
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
