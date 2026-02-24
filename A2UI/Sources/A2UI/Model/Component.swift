import Foundation

/// A single component in the UI definition.
///
/// Components are stored in a flat map keyed by `id`. The `type` field
/// (parsed from `"component"` in JSON) determines which `CatalogItem`
/// builder is used for rendering.
public struct Component: Equatable {

    /// The unique identifier for this component instance.
    public let id: String

    /// The component type name (e.g. "Text", "Button", "Column").
    public let type: String

    /// All properties of the component (JSON keys minus `id` and `component`).
    public let properties: JsonMap

    public init(id: String, type: String, properties: JsonMap = [:]) {
        self.id = id
        self.type = type
        self.properties = properties
    }

    // MARK: - JSON

    /// Creates a `Component` from a JSON dictionary.
    ///
    /// Expects keys `"id"` and `"component"`. All other keys become `properties`.
    public static func fromJSON(_ json: JsonMap) throws -> Component {
        guard let id = json["id"] as? String else {
            throw A2UIValidationError(message: "Component missing 'id' field")
        }
        guard let type = json["component"] as? String else {
            throw A2UIValidationError(message: "Component missing 'component' field")
        }
        var properties = json
        properties.removeValue(forKey: "id")
        properties.removeValue(forKey: "component")
        return Component(id: id, type: type, properties: properties)
    }

    /// Serializes this component back to a JSON dictionary.
    public func toJSON() -> JsonMap {
        var json = properties
        json["id"] = id
        json["component"] = type
        return json
    }

    // MARK: - Equatable

    public static func == (lhs: Component, rhs: Component) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type
    }
}
