// ============================================
// File: Views/Main/Components/EntryComposer.swift
// ============================================
import SwiftUI

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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.66))
                .scaleEffect(pulseEditor ? 0.98 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(pulseEditor ? 1 : 0.08), lineWidth: pulseEditor ? 3 : 1)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
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

struct NewEntryComposerOverlay: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var text: String
    @Binding var isSubmitting: Bool

    var isNetworkConnected: Bool
    var onCancel: () -> Void
    var onSave: () async -> Bool

    @FocusState private var isTextEditorFocused: Bool
    @State private var hasSettled = false

    private var isSaveDisabled: Bool {
        isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isNetworkConnected
    }

    var body: some View {
        GeometryReader { proxy in
            let usesAccessibilityLayout = dynamicTypeSize.brainMailUsesAccessibilityLayout
            let layout = NewEntryOverlayLayout(
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                usesAccessibilityLayout: usesAccessibilityLayout
            )

            ZStack(alignment: .top) {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }
                    .accessibilityHidden(true)

                composerCard(
                    layout: layout,
                    usesAccessibilityLayout: usesAccessibilityLayout
                )
                .frame(width: layout.cardWidth)
                .frame(
                    minHeight: layout.cardMinHeight,
                    idealHeight: layout.cardIdealHeight,
                    maxHeight: layout.cardMaxHeight,
                    alignment: .topLeading
                )
                .padding(.top, layout.topPadding)
                .scaleEffect(hasSettled ? 1 : 0.9, anchor: .top)
                .opacity(hasSettled ? 1 : 0)
                .offset(y: hasSettled ? 0 : -10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityIdentifier("home.entryComposer.overlay")
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                hasSettled = true
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 190_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isTextEditorFocused = true
            }
        }
        .onDisappear {
            isTextEditorFocused = false
            hasSettled = false
        }
        .brainMailDynamicTypeRange()
    }

    private func composerCard(
        layout: NewEntryOverlayLayout,
        usesAccessibilityLayout: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: layout.verticalSpacing) {
            Text("New entry")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.78))
                .lineLimit(usesAccessibilityLayout ? 2 : 1)
                .minimumScaleFactor(usesAccessibilityLayout ? 0.9 : 0.86)
                .fixedSize(horizontal: false, vertical: true)

            ExpandingEntryEditor(
                text: $text,
                placeholder: "What’s something worth remembering?",
                minHeight: layout.editorMinHeight,
                accessibilityIdentifier: "home.entryTextEditor",
                focus: $isTextEditorFocused
            )
            .layoutPriority(1)

            if !isNetworkConnected {
                Text("Connect to the internet to save.")
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            Spacer(minLength: layout.actionTopSpacing)

            actionRow(usesAccessibilityLayout: usesAccessibilityLayout)
                .layoutPriority(2)
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, layout.topContentPadding)
        .padding(.bottom, layout.bottomContentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.10), radius: 24, x: 0, y: 14)
        .accessibilityElement(children: .contain)
    }

    private func actionRow(usesAccessibilityLayout: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                isTextEditorFocused = false
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.figmaBlue.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 4)
                    .frame(minHeight: usesAccessibilityLayout ? 50 : 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.entryComposer.overlay.cancel")

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
            .accessibilityIdentifier("home.entryComposer.overlay.save")
        }
    }
}

private struct NewEntryOverlayLayout {
    let cardWidth: CGFloat
    let cardMinHeight: CGFloat
    let cardIdealHeight: CGFloat
    let cardMaxHeight: CGFloat
    let editorMinHeight: CGFloat
    let topPadding: CGFloat
    let horizontalPadding: CGFloat
    let topContentPadding: CGFloat
    let bottomContentPadding: CGFloat
    let verticalSpacing: CGFloat
    let actionTopSpacing: CGFloat

    init(
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets,
        usesAccessibilityLayout: Bool
    ) {
        let width = max(containerSize.width, 1)
        let height = max(containerSize.height, 1)
        let horizontalMargin = min(max(width * 0.06, 18), usesAccessibilityLayout ? 30 : 28)
        let maxCardWidth: CGFloat = usesAccessibilityLayout ? 560 : 500
        cardWidth = min(maxCardWidth, max(width - horizontalMargin * 2, 1))

        let safeTop = max(safeAreaInsets.top, 0)
        let safeBottom = max(safeAreaInsets.bottom, 0)
        topPadding = safeTop + min(max(width * 0.06, 18), usesAccessibilityLayout ? 28 : 30)

        let usableHeight = max(height - safeTop - safeBottom, 1)
        let bottomBreathingRoom = max(safeBottom, usesAccessibilityLayout ? 14 : 18)
        let fittingHeight = max(height - topPadding - bottomBreathingRoom, 1)
        let preferredMaxHeight = usableHeight * (usesAccessibilityLayout ? 0.78 : 0.66)
        let minimumUsefulMaxHeight = usableHeight * (usesAccessibilityLayout ? 0.58 : 0.52)
        cardMaxHeight = max(1, min(fittingHeight, max(preferredMaxHeight, minimumUsefulMaxHeight)))
        cardIdealHeight = max(1, min(cardMaxHeight, usableHeight * (usesAccessibilityLayout ? 0.70 : 0.60)))
        cardMinHeight = max(1, min(cardIdealHeight, cardMaxHeight * (usesAccessibilityLayout ? 0.80 : 0.76)))
        editorMinHeight = max(1, cardMaxHeight * (usesAccessibilityLayout ? 0.26 : 0.30))

        horizontalPadding = min(max(cardWidth * 0.07, 18), usesAccessibilityLayout ? 28 : 24)
        topContentPadding = usesAccessibilityLayout ? 24 : 22
        bottomContentPadding = usesAccessibilityLayout ? 20 : 18
        verticalSpacing = usesAccessibilityLayout ? 14 : 12
        actionTopSpacing = usesAccessibilityLayout ? 12 : 10
    }
}

private struct ExpandingEntryEditor: View {
    @Binding var text: String

    let placeholder: String
    let minHeight: CGFloat
    let accessibilityIdentifier: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused(focus)
                .frame(minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(.black)
                .font(.body)
                .textInputAutocapitalization(.sentences)
                .accessibilityIdentifier(accessibilityIdentifier)

            if text.isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(Color.black.opacity(0.36))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.025), radius: 7, x: 0, y: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

struct NewEntryComposerSheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var text: String
    @Binding var isSubmitting: Bool

    var isNetworkConnected: Bool
    var onCancel: () -> Void
    var onSave: () async -> Bool

    @FocusState private var isTextEditorFocused: Bool
    @State private var handledDismissal = false

    private var isSaveDisabled: Bool {
        isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isNetworkConnected
    }

    var body: some View {
        ZStack {
            BrainMailComposeSheetBackground()

            VStack(alignment: .leading, spacing: 0) {
                BrainMailComposeSheetHeader(
                    title: "New entry"
                )
                .padding(.bottom, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 24 : 22)

                BrainMailComposeInputBox(
                    text: $text,
                    placeholder: "",
                    minHeight: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 230 : 190,
                    accessibilityIdentifier: "home.entryTextEditor",
                    focus: $isTextEditorFocused
                )

                if !isNetworkConnected {
                    Text("Connect to the internet to save.")
                        .font(.caption)
                        .foregroundStyle(Color.red.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                }

                Spacer(minLength: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 24 : 20)

                HStack(alignment: .center, spacing: 12) {
                    Button {
                        handledDismissal = true
                        isTextEditorFocused = false
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.figmaBlue.opacity(0.86))
                            .padding(.horizontal, 4)
                            .frame(minHeight: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 50 : 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.entryComposer.sheet.cancel")

                    Spacer(minLength: 12)

                    Button {
                        guard !isSaveDisabled else { return }
                        handledDismissal = true
                        Task {
                            let didSave = await onSave()
                            if !didSave {
                                handledDismissal = false
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
            .padding(.horizontal, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 28 : 24)
            .padding(.top, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 48 : 44)
            .padding(.bottom, dynamicTypeSize.brainMailUsesAccessibilityLayout ? 22 : 18)
        }
        .accessibilityIdentifier("home.entryComposer.sheet")
        .presentationDragIndicator(.visible)
        .task {
            await Task.yield()
            guard !handledDismissal else { return }
            isTextEditorFocused = true
        }
        .onDisappear {
            isTextEditorFocused = false
            if !handledDismissal {
                onCancel()
            }
        }
        .brainMailDynamicTypeRange()
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
