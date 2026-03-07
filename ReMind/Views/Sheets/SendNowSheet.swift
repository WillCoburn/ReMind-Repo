// ============================
// File: Views/Sheets/SendNowSheet.swift
// ============================
import SwiftUI
import UIKit

@MainActor
struct SendNowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appVM: AppViewModel
    @ObservedObject private var revenueCat: RevenueCatManager = .shared

    @State private var isSending = false
    @State private var errorMessage: String? = nil
    @State private var showWeeklyLimitAlert = false

    var body: some View {
        let _ = revenueCat.entitlementActive
        NavigationView {
            ZStack {
                // Base → white, then soft blue overlay (matches ExportSheet)
                Color.white
                Color.blue.opacity(0.08)

                VStack {
                    Spacer()

                    // --- Centered icon + message block (mirrors ExportSheet layout) ---
                    VStack(spacing: 24) {
                        if isSending {
                            ProgressView("Sending reminder…")
                                .progressViewStyle(.circular)
                        } else {
                            Image("bellicon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 215, height: 215)
                        }

                        VStack(spacing: 6) {
                            Text("Need a reminder right now?")
                                .font(.subheadline) // same size as ExportSheet message
                                .foregroundColor(Color.black.opacity(0.65)) // same color as ExportSheet

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    }

                    Spacer()

                    // --- Bottom buttons (styled like ExportSheet) ---
                    VStack(spacing: 12) {
                        Button {
                            Task { await sendNow() }
                        } label: {
                            Group {
                                if isSending {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Text me!")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .foregroundColor(.white)
                        .background((isSending || appVM.hasUsedFreeInstantSendThisWeek) ? Color.figmaBlue.opacity(0.6) : Color.figmaBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .disabled(isSending)

                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .background(Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Send One Now")
                        .font(.headline)
                        .foregroundColor(.black)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Weekly Instant Send Used", isPresented: $showWeeklyLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You already used your weekly instant send, upgrade for unlimited!")
        }
    }

    private func sendNow() async {
        guard !isSending else { return }
        if appVM.hasUsedFreeInstantSendThisWeek {
            showWeeklyLimitAlert = true
            return
        }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            try await appVM.sendOneNow()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
