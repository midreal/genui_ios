import Foundation
import Combine

/// Utilities for resolving A2UI value definitions that may be literals,
/// data-binding references (`{path: "..."}`), or function calls
/// (`{call: "...", args: {...}}`).
///
/// Mirrors the BoundString/BoundNumber/BoundBool pattern from the Flutter
/// implementation, adapted for Combine publishers.
public enum BoundValueHelpers {

    // MARK: - Read (one-way) binding

    /// Resolves any value definition into a `String?` publisher.
    ///
    /// - `{path: "..."}` → subscribes to the data model
    /// - `{call: "...", args: {...}}` → evaluates the function reactively
    /// - literal String → emits directly
    /// - other → `nil`
    public static func resolveString(
        _ value: Any?,
        context: DataContext
    ) -> AnyPublisher<String?, Never> {
        context.resolve(value)
            .map { result -> String? in
                result.flatMap { $0 as? String ?? "\($0)" }
            }
            .eraseToAnyPublisher()
    }

    /// Resolves any value definition into a `Bool?` publisher.
    public static func resolveBool(
        _ value: Any?,
        context: DataContext
    ) -> AnyPublisher<Bool?, Never> {
        if let b = value as? Bool {
            return Just(b as Bool?).eraseToAnyPublisher()
        }
        return context.resolve(value)
            .map { result -> Bool? in
                guard let r = result else { return nil }
                if let b = r as? Bool { return b }
                if let s = r as? String {
                    if s.lowercased() == "true" { return true }
                    if s.lowercased() == "false" { return false }
                }
                if let n = r as? NSNumber { return n.boolValue }
                return nil
            }
            .eraseToAnyPublisher()
    }

    /// Resolves any value definition into a `Double?` publisher.
    public static func resolveNumber(
        _ value: Any?,
        context: DataContext
    ) -> AnyPublisher<Double?, Never> {
        if let n = value as? NSNumber {
            return Just(n.doubleValue as Double?).eraseToAnyPublisher()
        }
        return context.resolve(value)
            .map { result -> Double? in
                guard let r = result else { return nil }
                if let n = r as? NSNumber { return n.doubleValue }
                if let s = r as? String { return Double(s) }
                return nil
            }
            .eraseToAnyPublisher()
    }

    /// Resolves any value definition into a generic `Any?` publisher.
    public static func resolveAny(
        _ value: Any?,
        context: DataContext
    ) -> AnyPublisher<Any?, Never> {
        context.resolve(value)
    }

    // MARK: - Write path extraction

    /// Extracts the writable data-model path from a value definition.
    ///
    /// Returns a path string for two-way binding scenarios:
    /// - Plain `String` → treated as a path (backward-compat with `binding`)
    /// - `{path: "..."}` → extracts the path
    /// - Literal / function call / anything else → `nil` (read-only)
    public static func extractWritablePath(_ value: Any?) -> String? {
        if let str = value as? String {
            return str
        }
        if let map = value as? JsonMap, let path = map["path"] as? String {
            return path
        }
        return nil
    }

    // MARK: - Value reading with backward compatibility

    /// Reads the value definition from component data, with backward
    /// compatibility for the legacy `binding` field.
    ///
    /// Precedence: `value` → `binding` (treated as path string)
    public static func readValueDef(from data: JsonMap) -> Any? {
        if let v = data["value"] { return v }
        if let b = data["binding"] as? String { return ["path": b] as JsonMap }
        return nil
    }
}
