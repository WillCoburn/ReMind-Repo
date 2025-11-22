// ===========================================================
// File: Views/Settings/Sections/FeedbackSupportSection.swift
// ===========================================================
import SwiftUI
import MessageUI

struct FeedbackSupportSection: View {
    @Binding var showMailSheet: Bool
    @Binding var mailError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feedback & Support")
                .font(.subheadline.weight(.semibold))

            Button {
                openSupport()
            } label: {
                Label("Contact Us", systemImage: "envelope.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)
            }

            if let mailError {
                Text(mailError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func openSupport() {
        mailError = nil
        if MFMailComposeViewController.canSendMail() {
            showMailSheet = true
            return
        }
        let addr = "remindapphelp@gmail.com"
        let subject = "Re[Mind] Feedback"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Feedback"
        if let url = URL(string: "mailto:\(addr)?subject=\(encodedSubject)") {
            UIApplication.shared.open(url) { success in
                if !success { mailError = "Couldn’t open Mail. Please email us at \(addr)." }
            }
        } else {
            mailError = "Couldn’t create email link. Please email us at \(addr)."
        }
    }
}
