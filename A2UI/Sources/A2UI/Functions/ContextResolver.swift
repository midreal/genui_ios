import Foundation
import Combine

/// Resolves all dynamic values in a context definition map
/// using the DataContext, returning a fully-resolved JsonMap.
public enum ContextResolver {

    /// Recursively resolves all values in the context definition.
    /// Values like `{"path": "/some/path"}` are resolved to their current data model values.
    public static func resolveContext(
        _ dataContext: DataContext,
        _ contextDefinition: JsonMap?
    ) -> AnyPublisher<JsonMap, Never> {
        guard let definition = contextDefinition, !definition.isEmpty else {
            return Just([:]).eraseToAnyPublisher()
        }

        let keys = Array(definition.keys)
        let publishers = keys.map { key -> AnyPublisher<Any?, Never> in
            let value = definition[key]
            if let map = value as? JsonMap,
               map["path"] is String || map["call"] is String {
                return dataContext.resolve(map)
                    .first()
                    .eraseToAnyPublisher()
            }
            return Just(value).eraseToAnyPublisher()
        }

        return CombineLatestHelper.combineAll(publishers)
            .first()
            .map { values -> JsonMap in
                var resolved = JsonMap()
                for (i, key) in keys.enumerated() {
                    resolved[key] = values[i]
                }
                return resolved
            }
            .eraseToAnyPublisher()
    }
}
