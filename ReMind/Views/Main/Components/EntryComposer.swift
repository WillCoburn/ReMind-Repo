// ============================================
// File: Views/Main/Components/EntryComposer.swift
// ============================================
import SwiftUI

private struct BrainMailEntryCardShell: View {
    var isPulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.66))
            .scaleEffect(isPulsing ? 0.98 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.74), lineWidth: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.figmaBlue.opacity(isPulsing ? 1 : 0.08), lineWidth: isPulsing ? 3 : 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }
}

struct EntryComposer: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var text: String
    var pulseEditor: Bool
    var inputHeight: CGFloat = 76
    var onBeginEditing: () -> Void

    var body: some View {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmedText.isEmpty
        let usesAccessibilityLayout = dynamicTypeSize.brainMailUsesAccessibilityLayout

        VStack(alignment: .leading, spacing: 12) {
            Text("New entry")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.72))
                .lineLimit(usesAccessibilityLayout ? 2 : 1)
                .minimumScaleFactor(usesAccessibilityLayout ? 0.92 : 0.86)

            collapsedWritingPreview(hasText: hasText)
        }
        .padding(16)
        .background {
            BrainMailEntryCardShell(isPulsing: pulseEditor)
        }
        .animation(.easeInOut(duration: 0.5), value: pulseEditor)
        .animation(.easeInOut(duration: 0.2), value: hasText)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.entryComposer.compact")
        .frame(maxWidth: .infinity, alignment: .leading)
        .brainMailDynamicTypeRange()
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onBeginEditing)
    }

    private func collapsedWritingPreview(hasText: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            writingSurfaceBackground(hasText: hasText)

            if hasText {
                Text(text)
                    .font(.body)
                    .foregroundColor(Color.black.opacity(0.66))
                    .lineLimit(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 15 : 14, weight: .semibold))
                        .foregroundStyle(Color.figmaBlue.opacity(0.36))

                    Text("Tap to write to future you...")
                        .font(.body)
                        .foregroundColor(Color.black.opacity(0.38))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .lineLimit(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 3 : 2)
                .padding(.top, 14)
                .padding(.horizontal, 16)
            }
        }
        .frame(height: inputHeight, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private func writingSurfaceBackground(hasText: Bool) -> some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .fill(Color.white.opacity(0.48))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Color.figmaBlue.opacity(hasText ? 0.08 : 0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.025), radius: 7, x: 0, y: 3)
    }
}

struct EntryComposerOpeningGhost: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let inputHeight: CGFloat
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 16 : 12) {
            Text("New entry")
                .font(isExpanded ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(isExpanded ? 0.80 : 0.72))
                .fixedSize(horizontal: false, vertical: true)

            if isExpanded {
                Text("Write something you'd want to receive later.")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            writingPreview
        }
        .padding(isExpanded ? 20 : 16)
        .frame(maxWidth: .infinity, maxHeight: isExpanded ? .infinity : nil, alignment: .topLeading)
        .background {
            BrainMailEntryCardShell()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var writingPreview: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: isExpanded ? 18 : 17, style: .continuous)
                .fill(Color.white.opacity(isExpanded ? 0.52 : 0.48))
                .overlay(
                    RoundedRectangle(cornerRadius: isExpanded ? 18 : 17, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(0.06), lineWidth: 1)
                )

            if isExpanded {
                Text("What’s something worth remembering?")
                    .font(.body)
                    .foregroundStyle(Color.black.opacity(0.36))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .transition(.opacity)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 15 : 14, weight: .semibold))
                        .foregroundStyle(Color.figmaBlue.opacity(0.36))

                    Text("Tap to write to future you...")
                        .font(.body)
                        .foregroundColor(Color.black.opacity(0.38))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .lineLimit(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 3 : 2)
                .padding(.top, 14)
                .padding(.horizontal, 16)
            }
        }
        .frame(minHeight: inputHeight, maxHeight: isExpanded ? .infinity : inputHeight, alignment: .topLeading)
    }
}

struct NewEntryComposerSheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var text: String
    @Binding var isSubmitting: Bool

    let isNetworkConnected: Bool
    var onCancel: () -> Void
    var onSave: () async -> Bool

    @FocusState private var isTextEditorFocused: Bool
    @State private var isContentVisible = false

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.brainMailUsesAccessibilityLayout
    }

    private var isSaveDisabled: Bool {
        isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isNetworkConnected
    }

    var body: some View {
        if #available(iOS 16.4, *) {
            sheetContent
                .presentationBackground(.clear)
        } else {
            sheetContent
        }
    }

    private var sheetContent: some View {
        ZStack {
            BrainMailComposeSheetBackground()

            ViewThatFits(in: .vertical) {
                regularContent
                constrainedContent
            }
        }
        .opacity(isContentVisible ? 1 : 0)
        .accessibilityIdentifier("home.entryComposer.sheet")
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            isContentVisible = false
            isTextEditorFocused = false
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.14)) {
                isContentVisible = true
            }
            try? await Task.sleep(nanoseconds: 130_000_000)
            guard !Task.isCancelled else { return }
            isTextEditorFocused = true
        }
        .onDisappear {
            isTextEditorFocused = false
        }
        .brainMailDynamicTypeRange()
    }

    private var regularContent: some View {
        VStack(alignment: .leading, spacing: usesAccessibilityLayout ? 18 : 16) {
            header

            editor(minHeight: usesAccessibilityLayout ? 148 : 168)

            connectionMessage

            Spacer(minLength: usesAccessibilityLayout ? 18 : 16)

            actionRow
        }
        .padding(.horizontal, usesAccessibilityLayout ? 28 : 24)
        .padding(.top, usesAccessibilityLayout ? 48 : 44)
        .padding(.bottom, usesAccessibilityLayout ? 22 : 18)
    }

    private var constrainedContent: some View {
        VStack(alignment: .leading, spacing: usesAccessibilityLayout ? 14 : 12) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: usesAccessibilityLayout ? 18 : 16) {
                    header
                    editor(minHeight: usesAccessibilityLayout ? 112 : 126)
                    connectionMessage
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .layoutPriority(1)

            actionRow
        }
        .padding(.horizontal, usesAccessibilityLayout ? 28 : 24)
        .padding(.top, usesAccessibilityLayout ? 40 : 36)
        .padding(.bottom, usesAccessibilityLayout ? 22 : 18)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: usesAccessibilityLayout ? 10 : 8) {
            BrainMailComposeSheetHeader(title: "New entry")

            Text("Write something you'd want to receive later.")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editor(minHeight: CGFloat) -> some View {
        BrainMailComposeInputBox(
            text: $text,
            placeholder: "What’s something worth remembering?",
            minHeight: minHeight,
            accessibilityIdentifier: "home.entryTextEditor",
            focus: $isTextEditorFocused
        )
    }

    @ViewBuilder
    private var connectionMessage: some View {
        if !isNetworkConnected {
            Text("Connect to the internet to save.")
                .font(.caption)
                .foregroundStyle(Color.red.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                isTextEditorFocused = false
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.figmaBlue.opacity(0.86))
                    .frame(minHeight: usesAccessibilityLayout ? 50 : 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.entryComposer.sheet.cancel")

            Spacer(minLength: 12)

            Button {
                guard !isSaveDisabled else { return }
                Task { @MainActor in
                    let didSave = await onSave()
                    if !didSave {
                        isTextEditorFocused = true
                    }
                }
            } label: {
                BrainMailComposePrimaryButtonLabel(
                    title: "Save",
                    loadingTitle: "Saving…",
                    isLoading: isSubmitting,
                    isDisabled: isSaveDisabled
                )
            }
            .disabled(isSaveDisabled)
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.entryComposer.sheet.save")
        }
    }
}

struct BrainMailComposeSheetBackground: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Color.blue.opacity(0.04)
                .ignoresSafeArea()
        }
    }
}

struct BrainMailComposeSheetHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.84))
            .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BrainMailComposeInputBox: View {
    @Binding var text: String

    let placeholder: String
    var minHeight: CGFloat = 160
    var accessibilityIdentifier: String
    var focus: FocusState<Bool>.Binding

    init(
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat = 160,
        accessibilityIdentifier: String,
        focus: FocusState<Bool>.Binding
    ) {
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.accessibilityIdentifier = accessibilityIdentifier
        self.focus = focus
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused(focus)
                .frame(minHeight: minHeight, alignment: .topLeading)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(.black)
                .font(.body)
                .textInputAutocapitalization(.sentences)
                .accessibilityIdentifier(accessibilityIdentifier)

            if text.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

struct BrainMailComposePrimaryButtonLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let loadingTitle: String
    let isLoading: Bool
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }

            Text(isLoading ? loadingTitle : title)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 12 : 10)
        .background(
            Capsule()
                .fill(Color.figmaBlue.opacity(isDisabled ? 0.58 : 1))
        )
        .opacity(isDisabled ? 0.68 : 1)
    }
}
