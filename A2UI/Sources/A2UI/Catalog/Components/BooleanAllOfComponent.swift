import UIKit
import Combine

/// A logic-only component that computes AND across input booleans and
/// writes the result to an output boolean path.
///
/// Parameters:
/// - `inputs`: Array of boolean references to aggregate. Null values are treated as false.
/// - `output`: Object with `path` (required) and optional `literalBoolean` initial value.
enum BooleanAllOfComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "BooleanAllOf") { context in
            let wrapper = BindableView()

            let inputs = context.data["inputs"] as? [Any] ?? []
            let output = context.data["output"] as? JsonMap ?? [:]
            let outputPath = output["path"] as? String ?? ""

            guard !outputPath.isEmpty else {
                return wrapper
            }

            if let literal = output["literalBoolean"] as? Bool {
                context.dataContext.update(pathString: outputPath, value: literal)
            }

            var publishers: [AnyPublisher<Bool?, Never>] = []
            for input in inputs {
                let inputPath = (input as? JsonMap)?["path"] as? String
                if inputPath == outputPath { continue }
                let pub = BoundValueHelpers.resolveBool(input, context: context.dataContext)
                publishers.append(pub)
            }

            guard !publishers.isEmpty else {
                context.dataContext.update(pathString: outputPath, value: false)
                return wrapper
            }

            let combined: AnyPublisher<Bool, Never>
            if publishers.count == 1 {
                combined = publishers[0]
                    .map { $0 == true }
                    .eraseToAnyPublisher()
            } else {
                combined = publishers.dropFirst()
                    .reduce(publishers[0].map { $0 == true }.eraseToAnyPublisher()) { acc, next in
                        acc.combineLatest(next.map { $0 == true })
                            .map { $0 && $1 }
                            .eraseToAnyPublisher()
                    }
            }

            let cancellable = combined
                .receive(on: DispatchQueue.main)
                .sink { [weak wrapper] value in
                    guard wrapper != nil else { return }
                    context.dataContext.update(pathString: outputPath, value: value)
                }
            wrapper.storeCancellable(cancellable)

            return wrapper
        }
    }
}
