// ========================
// File: Utils/Design+Utils.swift
// ========================
import SwiftUI

extension DynamicTypeSize {
    var brainMailUsesAccessibilityLayout: Bool {
        isAccessibilitySize
    }
}

extension View {
    @ViewBuilder
    func brainMailDynamicTypeRange(_ allowsAccessibility: Bool = true) -> some View {
        if allowsAccessibility {
            dynamicTypeSize(.xSmall ... .accessibility5)
        } else {
            dynamicTypeSize(.xSmall ... .xxxLarge)
        }
    }
}

extension View {
    func cardStyle() -> some View {
        self.padding()
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(UIColor.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.15)))
    }
}
