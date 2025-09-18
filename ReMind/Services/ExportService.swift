// ============================
// File: Services/ExportService.swift
// ============================
import Foundation


protocol ExportService {
func generatePDF(from affirmations: [Affirmation]) async throws -> Data
func emailPDF(_ data: Data, to email: String) async throws
}
