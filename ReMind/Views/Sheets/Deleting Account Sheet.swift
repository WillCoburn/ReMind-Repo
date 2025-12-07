// ============================
// File: Views/Sheets/DeleteAccountSheet.swift
// ============================
import SwiftUI

struct DeleteAccountSheet: View {
    @EnvironmentObject private var appVM: AppViewModel

    @Binding var isPresented: Bool

    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // 1) White base + light blue overlay
                Color.white
                    .ignoresSafeArea()
                Color.blue.opacity(0.05)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    // 4) Danger icon in the middle
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                    // 2) Title text change
                    Text("Are you sure?")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.black)

                    Text("This will permanently remove your account, including all of your entries. This action cannot be undone.")
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .transition(.opacity)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        // 3) Light red pill background for destructive button
                        Button(role: .destructive) {
                            Task { await handleDelete() }
                        } label: {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.red)
                                }

                                Text(isDeleting ? "Deleting..." : "Yes, delete my account")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain) // so our custom pill style shows
                        .disabled(isDeleting)

                        Button("Cancel") {
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
            }
            .interactiveDismissDisabled(isDeleting)
        }
    }

    private func handleDelete() async {
        errorMessage = nil
        isDeleting = true

        do {
            try await appVM.deleteAccount()
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isDeleting = false
    }
}
