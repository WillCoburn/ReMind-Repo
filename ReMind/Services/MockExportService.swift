// ============================
// File: Services/MockExportService.swift
// ============================
import Foundation

public struct MockExportService: ExportService {
    public init() {}
    public func exportAndSend(entries: [Entry]) async throws -> URL {
        return URL(string: "https://example.com/fake.pdf")!
    }
}
