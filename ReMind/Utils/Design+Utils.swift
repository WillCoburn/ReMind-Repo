// ========================
// File: Utils/Design+Utils.swift
// ========================
import SwiftUI


extension View {
func cardStyle() -> some View {
self.padding()
.background(RoundedRectangle(cornerRadius: 20).fill(Color(UIColor.secondarySystemBackground)))
.overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.15)))
}
}
