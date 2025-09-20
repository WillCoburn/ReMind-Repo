// ===============================
// File: Services/MessagingService.swift
// ===============================
import Foundation

public protocol MessagingService {}

// No-op implementation so the app compiles/runs.
public struct NoopMessenger: MessagingService {
    public init() {}
}
