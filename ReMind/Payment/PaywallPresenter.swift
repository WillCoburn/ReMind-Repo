// ReMind/Payment/PaywallPresenter.swift
import Foundation
import SwiftUI

@MainActor
final class PaywallPresenter: ObservableObject {
    @Published var isPresenting: Bool = false

    func present(after dismissal: (() -> Void)? = nil) {
        if let dismissal {
            dismissal()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.isPresenting = true
            }
        } else {
            isPresenting = true
        }
    }

    func dismiss() {
        isPresenting = false
    }
}
