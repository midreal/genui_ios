import Foundation
import Combine

/// A function that can be invoked by the A2UI expression system.
///
/// Functions are reactive, returning a publisher of values. This allows functions
/// to push updates to the UI when their internal sources change.
public protocol ClientFunction {
    /// The name of the function as used in expressions (e.g. "formatString").
    var name: String { get }

    /// Invokes the function with resolved arguments.
    ///
    /// The returned publisher emits the function result. If arguments change,
    /// the caller will cancel the old subscription and re-invoke with new args.
    func execute(args: JsonMap, context: DataContext) -> AnyPublisher<Any?, Never>
}

/// Base class for synchronous client functions that produce a single result.
open class SynchronousClientFunction: ClientFunction {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public func execute(args: JsonMap, context: DataContext) -> AnyPublisher<Any?, Never> {
        Just(executeSync(args: args, context: context))
            .eraseToAnyPublisher()
    }

    /// Override this to provide the synchronous logic.
    open func executeSync(args: JsonMap, context: DataContext) -> Any? {
        nil
    }
}
