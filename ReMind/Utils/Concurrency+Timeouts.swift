import Foundation

enum TimeoutError: LocalizedError {
    case timeout(label: String)

    var errorDescription: String? {
        switch self {
        case .timeout(let label):
            return "Operation timed out: \(label)"
        }
    }
}

@discardableResult
func withTimeout<T>(seconds: TimeInterval, label: String, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            let thread = Thread.isMainThread ? "main" : "background"
            print("⏰ TIMEOUT: \(label) (on \(thread) thread)")
            throw TimeoutError.timeout(label: label)
        }

        guard let result = try await group.next() else {
            group.cancelAll()
            throw TimeoutError.timeout(label: label)
        }

        group.cancelAll()
        return result
    }
}

func runOffMain<T>(label: String, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await Task.detached(priority: .userInitiated) {
        let thread = Thread.isMainThread ? "main" : "background"
        print("🧵 \(label) executing on \(thread) thread")
        return try await operation()
    }.value
}
