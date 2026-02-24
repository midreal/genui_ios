import Foundation
import Combine

/// A scoped view of a `DataModel` at a specific path ("working directory").
///
/// Resolves relative paths against its base path. Supports dynamic value
/// resolution: literal values, data bindings (`{"path": "..."}`), and
/// function calls (`{"call": "...", "args": {...}}`).
public final class DataContext {

    private let dataModel: DataModelProtocol

    /// The base path of this context.
    public let path: DataPath

    private let functions: [String: ClientFunction]

    public init(
        dataModel: DataModelProtocol,
        path: DataPath = .root,
        functions: [ClientFunction] = []
    ) {
        self.dataModel = dataModel
        self.path = path
        self.functions = Dictionary(uniqueKeysWithValues: functions.map { ($0.name, $0) })
    }

    private init(dataModel: DataModelProtocol, path: DataPath, functions: [String: ClientFunction]) {
        self.dataModel = dataModel
        self.path = path
        self.functions = functions
    }

    /// The underlying data model.
    public var model: DataModelProtocol { dataModel }

    // MARK: - Path Resolution

    /// Resolves a path against this context's base path.
    public func resolvePath(_ pathToResolve: DataPath) -> DataPath {
        pathToResolve.isAbsolute ? pathToResolve : path.join(pathToResolve)
    }

    // MARK: - Data Access

    /// Subscribes to values at the given path (relative or absolute).
    public func subscribe(path: DataPath) -> AnyPublisher<Any?, Never> {
        dataModel.subscribe(path: resolvePath(path))
    }

    /// Subscribes to values at the given string path.
    public func subscribe(pathString: String) -> AnyPublisher<Any?, Never> {
        subscribe(path: DataPath(pathString))
    }

    /// Gets the current value at the given path.
    public func getValue(path: DataPath) -> Any? {
        dataModel.getValue(path: resolvePath(path))
    }

    /// Gets the current value at the given string path.
    public func getValue(pathString: String) -> Any? {
        getValue(path: DataPath(pathString))
    }

    /// Updates the data model at the given path.
    public func update(path: DataPath, value: Any?) {
        dataModel.update(path: resolvePath(path), value: value)
    }

    /// Updates the data model at the given string path.
    public func update(pathString: String, value: Any?) {
        update(path: DataPath(pathString), value: value)
    }

    // MARK: - Nesting

    /// Creates a child context for the given relative path.
    ///
    /// Used by list/template components to create per-item contexts.
    public func nested(_ relativePath: DataPath) -> DataContext {
        DataContext(dataModel: dataModel, path: resolvePath(relativePath), functions: functions)
    }

    /// Creates a child context for the given relative string path.
    public func nested(_ relativePathString: String) -> DataContext {
        nested(DataPath(relativePathString))
    }

    // MARK: - Dynamic Value Resolution

    /// Resolves a dynamic value: literal, data binding, or function call.
    ///
    /// - Literal values are emitted directly.
    /// - `{"path": "..."}` subscribes to the data model.
    /// - `{"call": "...", "args": {...}}` invokes a client function.
    public func resolve(_ value: Any?) -> AnyPublisher<Any?, Never> {
        if let map = value as? JsonMap {
            if let pathStr = map["path"] as? String {
                return subscribe(path: DataPath(pathStr))
            }
            if let callName = map["call"] as? String {
                return evaluateFunctionCall(name: callName, definition: map)
            }
        }
        return Just(value).eraseToAnyPublisher()
    }

    /// Evaluates a boolean condition and returns a publisher.
    public func evaluateConditionStream(_ condition: Any?) -> AnyPublisher<Bool, Never> {
        if condition == nil { return Just(false).eraseToAnyPublisher() }
        if let boolVal = condition as? Bool { return Just(boolVal).eraseToAnyPublisher() }

        return resolve(condition)
            .map { result in
                if let b = result as? Bool { return b }
                return result != nil
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Function Evaluation

    private func evaluateFunctionCall(name: String, definition: JsonMap) -> AnyPublisher<Any?, Never> {
        guard let function = functions[name] else {
            return Just(nil).eraseToAnyPublisher()
        }

        guard let argsMap = definition["args"] as? JsonMap else {
            return function.execute(args: [:], context: self)
        }

        let keys = Array(argsMap.keys)
        let argPublishers = keys.map { key -> AnyPublisher<Any?, Never> in
            resolve(argsMap[key])
        }

        guard !argPublishers.isEmpty else {
            return function.execute(args: [:], context: self)
        }

        return CombineLatestHelper.combineAll(argPublishers)
            .flatMap { [weak self] (values: [Any?]) -> AnyPublisher<Any?, Never> in
                guard let self = self else { return Just(nil).eraseToAnyPublisher() }
                var resolvedArgs = JsonMap()
                for (i, key) in keys.enumerated() {
                    resolvedArgs[key] = values[i]
                }
                return function.execute(args: resolvedArgs, context: self)
            }
            .eraseToAnyPublisher()
    }

    /// Retrieves a client function by name.
    public func getFunction(name: String) -> ClientFunction? {
        functions[name]
    }
}

// MARK: - CombineLatest Extension for Dynamic Arrays

enum CombineLatestHelper {
    static func combineAll(_ publishers: [AnyPublisher<Any?, Never>]) -> AnyPublisher<[Any?], Never> {
        guard !publishers.isEmpty else {
            return Just([]).eraseToAnyPublisher()
        }

        var combined: AnyPublisher<[Any?], Never> = publishers[0]
            .map { [$0] }
            .eraseToAnyPublisher()

        for i in 1..<publishers.count {
            combined = combined
                .combineLatest(publishers[i])
                .map { arr, val in arr + [val] }
                .eraseToAnyPublisher()
        }

        return combined
    }
}
