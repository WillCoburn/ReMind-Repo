// ============================================
// File: Views/Main/Components/EntryComposer.swift
// ============================================
import SwiftUI

struct EntryComposer: View {
    @Binding var text: String
    @Binding var isSubmitting: Bool
    var isDisabled: Bool

    // Forward the parent's FocusState binding for keyboard control
    @FocusState var isEntryFieldFocused: Bool

    var onSubmit: () async -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TextField("Type an entry…", text: $text, axis: .vertical)
                .lineLimit(3...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.85))
                )
                .focused($isEntryFieldFocused)

            Button {
                Task { await onSubmit() }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
            }
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.4 : 1.0)
            .accessibilityLabel("Submit entry")
            .accessibilityHint(accessibilityHint)
        }
    }

    private var accessibilityHint: String {
        if isDisabled {
            return "Type something to enable."
        }
        return "Saves your entry."
    }
}
