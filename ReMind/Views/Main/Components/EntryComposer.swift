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
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

                TextEditor(text: $text)
                    .focused($isEntryFieldFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(minHeight: 150, alignment: .topLeading)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.primary)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Hey future me, remember…")
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
            }

            Button {
                Task { await onSubmit() }
            } label: {
                ZStack {
                    Text("Save")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .opacity(isSubmitting ? 0 : 1)

                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                }
            }
            
            .frame(maxWidth: .infinity)
            .background(isDisabled ? Color.figmaBlue.opacity(0.65) : Color.figmaBlue)
            .cornerRadius(12)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.6 : 1.0)
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
