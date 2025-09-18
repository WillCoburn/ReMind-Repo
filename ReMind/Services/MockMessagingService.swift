// =====================================
// File: Services/MockMessagingService.swift
// =====================================
import Foundation


struct MockMessagingService: MessagingService {
func scheduleForFutureDelivery(_ affirmation: Affirmation) async throws {
// No-op in mock. Production: call Cloud Function that handles 10%/day + 9am–midnight window.
}
}
