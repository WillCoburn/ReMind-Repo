// ============================================
// File: Views/Main/Components/EntryComposer.swift
// ============================================
import SwiftUI

struct EntryComposer: View {
    @Binding var text: String
    @Binding var isSubmitting: Bool
    var isDisabled: Bool
    var pulseEditor: Bool
    var inputHeight: CGFloat = 154

    // Forward the parent's FocusState binding for keyboard control
    @FocusState var isEntryFieldFocused: Bool

    var onSubmit: () async -> Void

    var body: some View {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmedText.isEmpty
        let isExpanded = isEntryFieldFocused

        VStack(alignment: .leading, spacing: 12) {
            Text("New reminder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isExpanded ? Color.figmaBlue : Color.black.opacity(0.72))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isExpanded ? 0.92 : 0.78))

                TextEditor(text: $text)
                    .focused($isEntryFieldFocused)
                    .padding(.top, 12)
                    .padding(.leading, 14)
                    .padding(.trailing, 14)
                    .padding(.bottom, 58)
                    .frame(minHeight: inputHeight, alignment: .topLeading)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(Color.black.opacity(0.84))
                    .font(.system(size: 17))
                    .scrollDisabled(true)

                if !hasText && !isEntryFieldFocused {
                    Text("Hey future me, remember…")
                        .foregroundColor(Color.black.opacity(0.34))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .font(.system(size: 17))
                        .allowsHitTesting(false)
                }

                saveButton()
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.figmaBlue.opacity(isExpanded ? 0.34 : 0.08), lineWidth: isExpanded ? 1.5 : 1)
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
    }

    private var accessibilityHint: String {
        if isDisabled { return "Type something to enable." }
        return "Saves your entry."
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
            .frame(height: 34)
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
}
