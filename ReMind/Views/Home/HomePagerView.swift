// =====================
// File: Views/Home/HomePagerView.swift
// =====================
import SwiftUI

struct HomePagerView: View {
    /// 0 = left (Community), 1 = center (MainView), 2 = right (placeholder)
    @State private var selection: Int = 1

    var body: some View {
        TabView(selection: $selection) {
            // LEFT: Community page
            CommunityView()
                .tag(0)

            // CENTER: your existing MainView (user's own entries)
            MainView()
                .tag(1)

            // RIGHT: placeholder for future features
            RightPanelPlaceholderView(onRequestPaywall: {})
                .tag(2)
        }
        // Snapchat-style horizontal paging
        .tabViewStyle(.page(indexDisplayMode: .never))
        // Keep bottom overlays pinned even when the keyboard is visible
           //.ignoresSafeArea(.keyboard, edges: .bottom)
        .ignoresSafeArea(edges: .horizontal)
    }
}
