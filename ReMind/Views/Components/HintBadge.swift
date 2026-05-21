// Views/Components/HintBadge.swift
import SwiftUI

struct HintBadge: View {
    let count: Int

    init(count: Int) {
        self.count = count
    }

    var body: some View {
        Group {
            if count > 0 {
                Text("Add more over time to make your reminders feel more varied.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.gray.opacity(0.12))
                            )
                    )
            }
        }
    }
}
