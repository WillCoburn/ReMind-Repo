//
//  CompletionCollapseBadge.swift
//  ReMind
//
//  Created by Will Coburn on 9/17/25.
//

import Foundation
import SwiftUI

struct CompletionCollapseBadge: View {
    var title: String = "You’re all set! We’ll start texting these back at random times."

    @State private var isFlashing = false
    @State private var isCollapsed = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text(title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .font(.footnote)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isFlashing ? Color.green : Color.accentColor)
                    .animation(.easeInOut(duration: 0.2), value: isFlashing)
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.green.opacity(0.35), lineWidth: 1)
        )
        // Collapse animation
        .opacity(isCollapsed ? 0 : 1)
        .frame(height: isCollapsed ? 0 : nil)
        .animation(.easeInOut(duration: 0.35), value: isCollapsed)
        .onAppear {
            // Flash to green, then collapse
            withAnimation(.easeInOut(duration: 0.2)) { isFlashing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.2)) { isFlashing = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.35)) { isCollapsed = true }
                }
            }
        }
    }
}
