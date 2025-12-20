// ReMind/Payment/PaywallPresenter.swift
import Foundation

final class PaywallPresenter: ObservableObject {
    @Published var isPresenting: Bool = false

    /// Presents the paywall, optionally after dismissing another sheet first to avoid nesting.
    func present(after dismissal: (() -> Void)? = nil) {
        guard let dismissal else {
            isPresenting = true
            return
        }

        dismissal()

        // Present after the dismissal animation completes to prevent stacked sheets.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isPresenting = true
        }
    }

    func dismiss() {
        isPresenting = false
    }
}
