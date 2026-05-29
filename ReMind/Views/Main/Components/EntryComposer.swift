// ============================================
// File: Views/Main/Components/EntryComposer.swift
// ============================================
import SwiftUI
import UIKit

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
    var isEditing: Bool
    var isSubmitting: Bool
    var isNetworkConnected: Bool
    @Binding var isEditorFocused: Bool
    var onCancel: () -> Void
    var onSave: () async -> Bool
    var onBeginEditing: () -> Void

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.brainMailUsesAccessibilityLayout
    }

    private var isSaveDisabled: Bool {
        isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isNetworkConnected
    }

    private var inlineEditorMinHeight: CGFloat {
        usesAccessibilityLayout ? 162 : 122
    }

    var body: some View {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmedText.isEmpty

        VStack(alignment: .leading, spacing: isEditing ? 14 : 12) {
            if isEditing {
                editingTitle
                inlineWritingEditor
                connectionMessage
                actionRow
                    .frame(maxWidth: .infinity, alignment: usesAccessibilityLayout ? .leading : .trailing)
            } else {
                Text("New entry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.72))
                    .lineLimit(usesAccessibilityLayout ? 2 : 1)
                    .minimumScaleFactor(usesAccessibilityLayout ? 0.92 : 0.86)

                collapsedWritingPreview(hasText: hasText)
            }
        }
        .padding(16)
        .background {
            BrainMailEntryCardShell(isPulsing: pulseEditor)
        }
        .animation(.easeInOut(duration: 0.5), value: pulseEditor)
        .animation(.easeOut(duration: 0.18), value: isEditing)
        .animation(.easeInOut(duration: 0.2), value: hasText)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isEditing ? "home.entryComposer.inline" : "home.entryComposer.compact")
        .frame(maxWidth: .infinity, alignment: .leading)
        .brainMailDynamicTypeRange()
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            if !isEditing {
                onBeginEditing()
            }
        }
    }

    private var editingTitle: some View {
        Text("New entry")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.72))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                isEditorFocused = false
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.figmaBlue.opacity(0.86))
                    .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.entryComposer.inline.cancel")

            Button {
                guard !isSaveDisabled else { return }
                Task { @MainActor in
                    let didSave = await onSave()
                    if !didSave {
                        isEditorFocused = true
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
            .accessibilityIdentifier("home.entryComposer.inline.save")
        }
    }

    private var inlineWritingEditor: some View {
        ZStack(alignment: .topLeading) {
            BrainMailInlineTextView(
                text: $text,
                isFirstResponder: $isEditorFocused,
                accessibilityIdentifier: "home.entryTextEditor"
            )
                .frame(minHeight: inlineEditorMinHeight, alignment: .topLeading)
                .padding(8)

            if text.isEmpty {
                Text("Hey future me, remember...")
                    .foregroundStyle(Color.black.opacity(0.38))
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(false)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.48))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(isEditorFocused ? 0.18 : 0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.025), radius: 7, x: 0, y: 3)
        }
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
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        collapsedPlaceholderIcon
                        collapsedPlaceholderText
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        collapsedPlaceholderIcon
                        collapsedPlaceholderText
                    }
                }
                .lineLimit(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 3 : 2)
                .padding(.top, 14)
                .padding(.horizontal, 16)
            }
        }
        .frame(minHeight: inputHeight, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private var collapsedPlaceholderIcon: some View {
        Image(systemName: "square.and.pencil")
            .font(.system(size: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 15 : 14, weight: .semibold))
            .foregroundStyle(Color.figmaBlue.opacity(0.36))
    }

    private var collapsedPlaceholderText: some View {
        Text("Tap to write to future you")
            .font(.body)
            .foregroundColor(Color.black.opacity(0.38))
            .fixedSize(horizontal: false, vertical: true)
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

private struct BrainMailInlineTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    let accessibilityIdentifier: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isOpaque = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .black
        textView.autocapitalizationType = .sentences
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.inputAccessoryView = nil
        textView.accessibilityIdentifier = accessibilityIdentifier
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            textView.text = text
        }

        if isFirstResponder {
            guard !textView.isFirstResponder else { return }
            DispatchQueue.main.async {
                guard self.isFirstResponder, textView.window != nil else { return }
                textView.becomeFirstResponder()
            }
        } else if textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    static func dismantleUIView(_ textView: UITextView, coordinator: Coordinator) {
        textView.resignFirstResponder()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BrainMailInlineTextView

        init(parent: BrainMailInlineTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFirstResponder = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFirstResponder = false
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
