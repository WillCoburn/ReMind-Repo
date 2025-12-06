// ============================
// File: Views/Onboarding/CodeEntrySection.swift
// ============================
import SwiftUI

struct CodeEntrySection: View {
    @Binding var code: String
    let phoneNumber: String
    let errorText: String
    let isVerifying: Bool
    let onEditNumber: () -> Void
    let onResend: () -> Void
    let onVerify: () -> Void
    
    @FocusState private var isCodeFieldFocused: Bool
    
    // Only allow digits & max length 6
    private var sanitizedBinding: Binding<String> {
        Binding(
            get: { code },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)
                code = String(digits.prefix(6))
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            
            // Back button row
            HStack {
                Button(action: onEditNumber) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                }
                Spacer()
            }
            
            // Title + description
            VStack(alignment: .center, spacing: 8) {
                Text("Phone Verification")
                    .font(.title2.weight(.semibold))
                
                    .frame(maxWidth: .infinity, alignment: .center)
                
                (Text("We've sent an SMS with an activation code to your phone ") +
                 Text(phoneNumber).foregroundColor(.figmaBlue))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
            }
            
            // 6-digit boxes
            codeBoxes
            
            // Resend
            Button("Resend code", action: onResend)
                .font(.body.weight(.medium))
                .foregroundColor(.figmaBlue)
            
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
        .onAppear { isCodeFieldFocused = true }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                // Error banner
                if !errorText.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(errorText)
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.35), lineWidth: 1)
                    )
                }
                
                // Verify button
                Button(action: onVerify) {
                    ZStack {
                        Text(isVerifying ? "Verifying…" : "Verify Code")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .opacity(isVerifying ? 0 : 1)
                        
                        if isVerifying {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(code.count == 6 ? Color.figmaBlue : Color.gray.opacity(0.35))
                    .cornerRadius(14)
                }
                .disabled(code.count < 6 || isVerifying)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial.opacity(0.001))
        }
    }
    
    // MARK: - Code Boxes UI
    private var codeBoxes: some View {
        ZStack {
            // Visible 6 boxes, perfectly centered
            HStack(spacing: 14) {
                let digits = Array(code)
                
                ForEach(0..<6, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor(for: index), lineWidth: 2)
                            .frame(width: 48, height: 48)
                            .animation(.easeInOut(duration: 0.15), value: code)
                        
                        Text(index < digits.count ? String(digits[index]) : "")
                            .font(.title2.weight(.semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Hidden text field powering the whole thing, NOT part of the HStack layout
            TextField("", text: sanitizedBinding)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isCodeFieldFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { isCodeFieldFocused = true }
    }
    
    // MARK: - Dynamic border highlight
    private func borderColor(for index: Int) -> Color {
        if index == code.count && code.count < 6 {
            return .figmaBlue
        }
        return Color.gray.opacity(0.35)
    }
}
