// ==================================
// File: Services/MockExportService.swift
// ==================================
import Foundation


struct MockExportService: ExportService {
func generatePDF(from entries: [Entry]) async throws -> Data {
// Placeholder: simple UTF-8 text blob to simulate generated PDF data.
let header = "ReMind – Your Affirmations\n\n"
let lines = entries.map { "• \($0.text)" }.joined(separator: "\n")
return Data((header + lines).utf8)
}


func emailPDF(_ data: Data, to email: String) async throws {
// No-op in mock. Production: send via SendGrid/SES.
}
}
