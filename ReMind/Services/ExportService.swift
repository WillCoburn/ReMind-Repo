// ============================
// File: Services/ExportService.swift
// ============================
import Foundation

public protocol ExportService {}

// No-op implementation so the app compiles/runs.
public struct NoopExporter: ExportService {
    public init() {}
}
