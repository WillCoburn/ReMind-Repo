// ============================================
// File: Views/Main/Components/EntryComposer.swift
// ============================================
import SwiftUI
import UIKit

struct EntryComposer: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var text: String
    @Binding var isSubmitting: Bool
    var isDisabled: Bool
    var pulseEditor: Bool
    var inputHeight: CGFloat = 154

    // Forward the parent's FocusState binding for keyboard control
    @FocusState var isEntryFieldFocused: Bool

    var onSubmit: () async -> Void
    var onCancel: () -> Void = {}

    var body: some View {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmedText.isEmpty
        let isExpanded = isEntryFieldFocused
        let usesAccessibilityLayout = dynamicTypeSize.brainMailUsesAccessibilityLayout

        VStack(alignment: .leading, spacing: 12) {
            Text("New reminder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isExpanded ? Color.figmaBlue : Color.black.opacity(0.72))
                .lineLimit(usesAccessibilityLayout ? 2 : 1)
                .minimumScaleFactor(usesAccessibilityLayout ? 0.92 : 0.82)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isExpanded ? 0.92 : 0.78))

                TextEditor(text: $text)
                    .focused($isEntryFieldFocused)
                    .accessibilityIdentifier("home.entryTextEditor")
                    .padding(.top, 12)
                    .padding(.leading, 14)
                    .padding(.trailing, 14)
                    .padding(.bottom, usesAccessibilityLayout ? 76 : 58)
                    .frame(height: inputHeight, alignment: .topLeading)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(Color.black.opacity(0.84))
                    .font(.body)
                    .textInputAutocapitalization(.sentences)

                if !hasText {
                    Text("Hey future me, remember…")
                        .foregroundColor(Color.black.opacity(0.34))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                }

                bottomControls(hasText: hasText, isExpanded: isExpanded)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.figmaBlue.opacity(isExpanded ? 0.34 : 0.08), lineWidth: isExpanded ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture {
                isEntryFieldFocused = true
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    handleDoubleTap()
                }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(isExpanded ? 0.84 : 0.72))
                .scaleEffect(pulseEditor ? 0.98 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.figmaBlue.opacity(pulseEditor ? 1 : 0.10), lineWidth: pulseEditor ? 3 : 1)
        )
        .shadow(color: Color.black.opacity(isExpanded ? 0.07 : 0.05), radius: isExpanded ? 22 : 16, x: 0, y: 8)
        .animation(.easeInOut(duration: 0.5), value: pulseEditor)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: isEntryFieldFocused)
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

    private func bottomControls(hasText: Bool, isExpanded: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                cancelButton(hasText: hasText, isExpanded: isExpanded)
                Spacer(minLength: 8)
                saveButton()
            }

            VStack(alignment: .trailing, spacing: 8) {
                cancelButton(hasText: hasText, isExpanded: isExpanded)
                saveButton()
            }
        }
    }

    @ViewBuilder
    private func cancelButton(hasText: Bool, isExpanded: Bool) -> some View {
        if isExpanded || hasText {
            Button {
                onCancel()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 0.92 : 0.82)
                    .padding(.horizontal, 13)
                    .frame(minHeight: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 42 : 34)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.68))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel reminder")
        }
    }

    private func saveButton() -> some View {
        Button {
            Task { await onSubmit() }
        } label: {
            ZStack {
                Text("Save")
                    .font(.subheadline.weight(.semibold))
                    .opacity(isSubmitting ? 0 : 1)

                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            .foregroundStyle(isDisabled ? Color.figmaBlue.opacity(0.55) : .white)
            .padding(.horizontal, 16)
            .frame(minHeight: dynamicTypeSize.brainMailUsesAccessibilityLayout ? 42 : 34)
            .lineLimit(1)
            .minimumScaleFactor(dynamicTypeSize.brainMailUsesAccessibilityLayout ? 0.92 : 0.82)
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
        .accessibilityLabel("Save reminder")
        .accessibilityHint(accessibilityHint)
    }

    private func handleDoubleTap() {
        isEntryFieldFocused = true
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty
        else {
            return
        }
        text = clipboardText
    }
}
