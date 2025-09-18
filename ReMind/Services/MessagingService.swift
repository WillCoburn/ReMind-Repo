// ==============================
// File: Services/MessagingService.swift
// ==============================
import Foundation


protocol MessagingService {
/// Enqueue for randomized future SMS (implemented server-side in production)
func scheduleForFutureDelivery(_ affirmation: Affirmation) async throws
}
