import SwiftUI

struct CommunityComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onPostSucceeded: (CommunityPost?) -> Void

    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var submissionState: CommunityPostSubmissionState?
    @State private var showSuccessCheckmark = false
    @FocusState private var isTextEditorFocused: Bool

    init(onPostSucceeded: @escaping (CommunityPost?) -> Void = { _ in }) {
        self.onPostSucceeded = onPostSucceeded
    }

    var body: some View {
        ZStack {
            BrainMailComposeSheetBackground()

            VStack(alignment: .leading, spacing: 0) {
                BrainMailComposeSheetHeader(
                    title: "Community note"
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
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.45 : 1)

                    Spacer(minLength: 12)

                    Button {
                        guard !isSubmitDisabled else { return }
                        Task { await handleSubmit() }
                    } label: {
                        BrainMailComposePrimaryButtonLabel(
                            title: "Post",
                            loadingTitle: "Posting…",
                            isLoading: isSubmitting,
                            isDisabled: isSubmitDisabled
                        )
                    }
                    .disabled(isSubmitDisabled)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 28 : 24)
            .padding(.top, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 48 : 44)
            .padding(.bottom, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 22 : 18)

            if let submissionState {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .transition(.opacity)

                CommunityPostingProgressCard(
                    state: submissionState,
                    showSuccessCheckmark: showSuccessCheckmark
                )
                .padding(.horizontal, 28)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSubmitting || submissionState == .success)
        .task {
            await Task.yield()
            isTextEditorFocused = true
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: submissionState)
        .animation(.spring(response: 0.32, dampingFraction: 0.74), value: showSuccessCheckmark)
        .brainMailDynamicTypeRange()
    }

    private var isSubmitDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting
    }

    private func handleSubmit() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmitting else { return }

        isSubmitting = true
        submissionState = .posting

        do {
            let createdPost = try await CommunityAPI.shared.createPost(text: trimmed)
            onPostSucceeded(createdPost)

            isSubmitting = false
            submissionState = .success
            withAnimation(.spring(response: 0.28, dampingFraction: 0.66)) {
                showSuccessCheckmark = true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        } catch {
            let nsError = error as NSError
            print("🔥 createCommunityPost error:", nsError, nsError.userInfo)
            isSubmitting = false
            submissionState = .failure
            showSuccessCheckmark = false
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if submissionState == .failure {
                submissionState = nil
            }
        }
    }
}

private enum CommunityPostSubmissionState: Equatable {
    case posting
    case success
    case failure

    var message: String {
        switch self {
        case .posting:
            return "Posting..."
        case .success:
            return "Shared successfully"
        case .failure:
            return "Unable to share right now. Please try again."
        }
    }
}

private struct CommunityPostingProgressCard: View {
    let state: CommunityPostSubmissionState
    let showSuccessCheckmark: Bool

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 42, height: 42)

                switch state {
                case .posting:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .figmaBlue))
                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.figmaBlue)
                        .scaleEffect(showSuccessCheckmark ? 1 : 0.58)
                        .opacity(showSuccessCheckmark ? 1 : 0)
                case .failure:
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.figmaBlue)
                }
            }

            Text(state.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.76))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
    }

    private var iconBackgroundColor: Color {
        switch state {
        case .posting:
            return Color.figmaBlue.opacity(0.12)
        case .success:
            return Color.figmaBlue.opacity(0.13)
        case .failure:
            return Color.figmaBlue.opacity(0.10)
        }
    }
}
