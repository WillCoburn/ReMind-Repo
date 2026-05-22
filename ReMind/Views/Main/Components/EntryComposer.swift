// ============================================
// File: Views/Main/Components/EntryComposer.swift
// ============================================
import SwiftUI
import UIKit

enum ComposerState: Equatable {
    case collapsed
    case focused
}

struct EntryComposer: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var text: String
    @Binding var isSubmitting: Bool
    @Binding var state: ComposerState
    var isDisabled: Bool
    var pulseEditor: Bool
    var inputHeight: CGFloat = 154

    @FocusState var isEntryFieldFocused: Bool

    var onSubmit: () async -> Void
    var onDismiss: () -> Void = {}

    var body: some View {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmedText.isEmpty
        let isExpanded = state == .focused
        let usesAccessibilityLayout = dynamicTypeSize.brainMailUsesAccessibilityLayout

        VStack(alignment: .leading, spacing: isExpanded ? 10 : 12) {
            Text("New entry")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isExpanded ? Color.figmaBlue.opacity(0.92) : Color.black.opacity(0.72))
                .lineLimit(usesAccessibilityLayout ? 2 : 1)
                .minimumScaleFactor(usesAccessibilityLayout ? 0.92 : 0.86)

            ZStack(alignment: .topLeading) {
                writingSurfaceBackground(isExpanded: isExpanded, hasText: hasText)

                TextEditor(text: $text)
                    .focused($isEntryFieldFocused)
                    .accessibilityIdentifier("home.entryTextEditor")
                    .padding(.horizontal, isExpanded ? 10 : 12)
                    .padding(.vertical, isExpanded ? 6 : 5)
                    .frame(height: inputHeight, alignment: .topLeading)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(Color.black.opacity(0.84))
                    .font(.body)
                    .textInputAutocapitalization(.sentences)
                    .scrollDisabled(!isExpanded)
                    .onTapGesture {
                        focusComposer()
                    }

                if !hasText {
                    placeholderContent(isExpanded: isExpanded)
                        .padding(.top, isExpanded ? 15 : 14)
                        .padding(.horizontal, isExpanded ? 15 : 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: inputHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture {
                focusComposer()
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    handleDoubleTap()
                }
            )

            if isExpanded {
                bottomControls
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(isExpanded ? 18 : 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(isExpanded ? 0.74 : 0.66))
                .scaleEffect(pulseEditor ? 0.98 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(isExpanded ? 0.82 : 0.72), lineWidth: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.figmaBlue.opacity(pulseEditor ? 1 : (isExpanded ? 0.18 : 0.08)), lineWidth: pulseEditor ? 3 : 1)
                )
        )
        .shadow(color: Color.black.opacity(isExpanded ? 0.08 : 0.04), radius: isExpanded ? 24 : 16, x: 0, y: isExpanded ? 12 : 8)
        .animation(.easeInOut(duration: 0.5), value: pulseEditor)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: state)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: inputHeight)
        .animation(.easeInOut(duration: 0.2), value: hasText)
        .accessibilityElement(children: .contain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brainMailDynamicTypeRange()
    }

    private var accessibilityHint: String {
        if isDisabled { return "Type something to enable." }
        return "Saves your entry."
    }

    private func writingSurfaceBackground(isExpanded: Bool, hasText: Bool) -> some View {
        RoundedRectangle(cornerRadius: isExpanded ? 18 : 17, style: .continuous)
            .fill(Color.white.opacity(isExpanded ? 0.56 : 0.48))
            .overlay(
                RoundedRectangle(cornerRadius: isExpanded ? 18 : 17, style: .continuous)
                    .stroke(
                        Color.figmaBlue.opacity(isExpanded ? 0.10 : (hasText ? 0.08 : 0.05)),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isExpanded ? 0.035 : 0.025),
                radius: isExpanded ? 10 : 7,
                x: 0,
                y: isExpanded ? 5 : 3
            )
    }

    private func placeholderContent(isExpanded: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isExpanded ? "pencil.line" : "square.and.pencil")
                .font(.system(size: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 15 : 14, weight: .semibold))
                .foregroundStyle(Color.figmaBlue.opacity(isExpanded ? 0.42 : 0.36))

            Text(isExpanded ? "Hey future me..." : "Tap to write to future you...")
                .font(.body)
                .foregroundColor(Color.black.opacity(isExpanded ? 0.34 : 0.38))
                .fixedSize(horizontal: false, vertical: true)
        }
        .lineLimit(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 3 : 2)
    }

    private var bottomControls: some View {
        HStack(alignment: .center, spacing: 12) {
            collapseButton

            Spacer(minLength: 12)

            saveButton
        }
        .frame(maxWidth: .infinity)
    }

    private var collapseButton: some View {
        Button {
            onDismiss()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 17 : 15, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.42))
                .frame(
                    width: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 46 : 42,
                    height: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 46 : 40
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Collapse entry composer")
    }

    private var saveButton: some View {
        Button {
            Task { await onSubmit() }
        } label: {
            HStack(spacing: 7) {
                if !isSubmitting {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                }

                Text("Save")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.82)
                }
            }
            .foregroundStyle(isDisabled ? Color.figmaBlue.opacity(0.55) : .white)
            .padding(.horizontal, 16)
            .frame(minHeight: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 46 : 40)
            .background(
                Capsule(style: .continuous)
                    .fill(isDisabled ? Color.figmaBlue.opacity(0.14) : Color.figmaBlue)
            )
            .shadow(
                color: isDisabled ? Color.clear : Color.figmaBlue.opacity(0.18),
                radius: 10,
                x: 0,
                y: 5
            )
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .accessibilityLabel("Save entry")
        .accessibilityHint(accessibilityHint)
    }

    private func focusComposer() {
        if state != .focused {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                state = .focused
            }
        }
    }

    private func handleDoubleTap() {
        focusComposer()
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty
        else {
            return
        }
        text = clipboardText
    }
}
