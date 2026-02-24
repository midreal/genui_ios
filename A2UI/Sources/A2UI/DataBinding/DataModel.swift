import Foundation
import Combine

/// Reactive data store protocol. Each surface has its own `DataModel`.
public protocol DataModelProtocol: AnyObject {
    /// Updates the value at the given absolute path, notifying all relevant subscribers.
    func update(path: DataPath, value: Any?)

    /// Returns a publisher that emits the current and future values at the given path.
    func subscribe(path: DataPath) -> AnyPublisher<Any?, Never>

    /// Returns the current value at the given path without subscribing.
    func getValue(path: DataPath) -> Any?

    /// Releases all resources.
    func dispose()
}

/// Standard in-memory implementation of `DataModelProtocol`.
///
/// Uses a nested `[String: Any]` tree for storage and `CurrentValueSubject`
/// instances for path-based subscriptions with three-way notification
/// (exact match + ancestor bubble + descendant propagation).
public final class InMemoryDataModel: DataModelProtocol {

    private var data: JsonMap = [:]
    private var subscriptions: [DataPath: CurrentValueSubject<Any?, Never>] = [:]
    private let lock = NSRecursiveLock()

    public init() {}

    // MARK: - DataModelProtocol

    public func update(path: DataPath, value: Any?) {
        lock.lock()
        defer { lock.unlock() }

        if path == .root {
            if let map = value as? JsonMap {
                data = map
            } else if value == nil {
                data = [:]
            }
            notifySubscribers(path: .root)
            return
        }

        updateNestedValue(&data, segments: path.segments, value: value)
        notifySubscribers(path: path)
    }

    public func subscribe(path: DataPath) -> AnyPublisher<Any?, Never> {
        lock.lock()
        defer { lock.unlock() }

        if let existing = subscriptions[path] {
            return existing.eraseToAnyPublisher()
        }
        let subject = CurrentValueSubject<Any?, Never>(getValue(path: path))
        subscriptions[path] = subject
        return subject.eraseToAnyPublisher()
    }

    public func getValue(path: DataPath) -> Any? {
        lock.lock()
        defer { lock.unlock() }

        if path == .root { return data }
        return getNestedValue(data, segments: path.segments)
    }

    public func dispose() {
        lock.lock()
        defer { lock.unlock() }

        for subject in subscriptions.values {
            subject.send(completion: .finished)
        }
        subscriptions.removeAll()
        data = [:]
    }

    // MARK: - Nested Value Operations

    private func getNestedValue(_ current: Any?, segments: [String]) -> Any? {
        guard !segments.isEmpty else { return current }
        let segment = segments[0]
        let remaining = Array(segments.dropFirst())

        if let dict = current as? JsonMap {
            return getNestedValue(dict[segment], segments: remaining)
        }
        if let arr = current as? [Any] {
            if let index = Int(segment), index >= 0, index < arr.count {
                return getNestedValue(arr[index], segments: remaining)
            }
        }
        return nil
    }

    private func updateNestedValue(_ current: inout JsonMap, segments: [String], value: Any?) {
        guard !segments.isEmpty else { return }
        let segment = segments[0]
        let remaining = Array(segments.dropFirst())

        if remaining.isEmpty {
            if value == nil {
                current.removeValue(forKey: segment)
            } else {
                current[segment] = value
            }
            return
        }

        var nextNode = current[segment]
        if nextNode == nil {
            if value == nil { return }
            let nextSegment = remaining[0]
            if Int(nextSegment) != nil {
                nextNode = [Any]()
            } else {
                nextNode = JsonMap()
            }
        }

        if var dict = nextNode as? JsonMap {
            updateNestedValue(&dict, segments: remaining, value: value)
            current[segment] = dict
        } else if var arr = nextNode as? [Any] {
            updateNestedArray(&arr, segments: remaining, value: value)
            current[segment] = arr
        }
    }

    private func updateNestedArray(_ current: inout [Any], segments: [String], value: Any?) {
        guard !segments.isEmpty else { return }
        let segment = segments[0]
        let remaining = Array(segments.dropFirst())
        guard let index = Int(segment), index >= 0 else { return }

        if remaining.isEmpty {
            if index < current.count {
                if let v = value {
                    current[index] = v
                }
            } else if index == current.count, let v = value {
                current.append(v)
            }
        } else {
            if index < current.count {
                if var dict = current[index] as? JsonMap {
                    updateNestedValue(&dict, segments: remaining, value: value)
                    current[index] = dict
                } else if var arr = current[index] as? [Any] {
                    updateNestedArray(&arr, segments: remaining, value: value)
                    current[index] = arr
                }
            } else if index == current.count {
                let nextSegment = remaining[0]
                if Int(nextSegment) != nil {
                    var newArr = [Any]()
                    updateNestedArray(&newArr, segments: remaining, value: value)
                    current.append(newArr)
                } else {
                    var newDict = JsonMap()
                    updateNestedValue(&newDict, segments: remaining, value: value)
                    current.append(newDict)
                }
            }
        }
    }

    // MARK: - Notification

    /// Notifies subscribers at the exact path, all ancestor paths (bubble up),
    /// all descendant paths (propagate down), and always the root.
    private func notifySubscribers(path: DataPath) {
        // Exact match
        if let subject = subscriptions[path] {
            subject.send(getValue(path: path))
        }

        // Ancestor paths (bubble up)
        var parent = path
        while parent.segments.count > 0 {
            parent = parent.dirname
            if let subject = subscriptions[parent] {
                subject.send(getValue(path: parent))
            }
        }

        // Root notification
        if path != .root, let rootSubject = subscriptions[.root] {
            rootSubject.send(getValue(path: .root))
        }

        // Descendant paths (propagate down)
        for (subscribedPath, subject) in subscriptions {
            if subscribedPath.starts(with: path) && subscribedPath != path {
                subject.send(getValue(path: subscribedPath))
            }
        }
    }
}
