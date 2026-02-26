import Foundation
import Combine

/// Reactive validation helper that evaluates `checks` arrays
/// (each containing `{condition, message}`) against the data model.
public enum ValidationHelper {

    /// Evaluates a list of checks and returns a stream emitting the first
    /// error message string, or `nil` if all checks pass.
    public static func validateStream(
        checks: [JsonMap]?,
        context: DataContext?
    ) -> AnyPublisher<String?, Never> {
        guard let checks = checks, !checks.isEmpty, let context = context else {
            return Just(nil).eraseToAnyPublisher()
        }

        let streams: [AnyPublisher<(Bool, String), Never>] = checks.map { check in
            let message = check["message"] as? String ?? "Invalid value"
            return context.evaluateConditionStream(check["condition"])
                .map { isValid in (isValid, message) }
                .eraseToAnyPublisher()
        }

        return CombineLatestHelper.combineAll(
            streams.map { $0.map { $0 as Any? }.eraseToAnyPublisher() }
        )
        .map { values -> String? in
            for value in values {
                guard let tuple = value as? (Bool, String) else { continue }
                if !tuple.0 { return tuple.1 }
            }
            return nil
        }
        .eraseToAnyPublisher()
    }

    /// Converts a list of `checks` into a single `and(...)` condition
    /// expression that evaluates to `true` when all checks pass.
    public static func checksToExpression(_ checks: [JsonMap]?) -> Any? {
        guard let checks = checks, !checks.isEmpty else { return true }
        return [
            "call": "and",
            "args": ["values": checks.compactMap { $0["condition"] }]
        ] as JsonMap
    }
}
