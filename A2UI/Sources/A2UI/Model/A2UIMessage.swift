import Foundation

/// A message in the A2UI protocol stream (v0.9 canonical).
///
/// v0.9 uses `createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`.
/// v0.8 messages (`beginRendering`, `surfaceUpdate`, `dataModelUpdate`) are automatically
/// converted to the v0.9 canonical form via `A2UIMessageV08Adapter`.
public enum A2UIMessage {
    case createSurface(CreateSurfacePayload)
    case updateComponents(UpdateComponentsPayload)
    case updateDataModel(UpdateDataModelPayload)
    case deleteSurface(surfaceId: String)

    /// A short human-readable name for the message type.
    public var typeName: String {
        switch self {
        case .createSurface: return "createSurface"
        case .updateComponents: return "updateComponents"
        case .updateDataModel: return "updateDataModel"
        case .deleteSurface: return "deleteSurface"
        }
    }

    /// The surface ID associated with this message.
    public var surfaceId: String {
        switch self {
        case .createSurface(let p): return p.surfaceId
        case .updateComponents(let p): return p.surfaceId
        case .updateDataModel(let p): return p.surfaceId
        case .deleteSurface(let id): return id
        }
    }

    /// Parses an `A2UIMessage` from a JSON dictionary.
    ///
    /// Supports both v0.9 (`createSurface`, `updateComponents`, `updateDataModel`)
    /// and v0.8 (`beginRendering`, `surfaceUpdate`, `dataModelUpdate`) formats.
    /// Throws if the version is explicitly set to an unsupported value.
    public static func fromJSON(_ json: JsonMap) throws -> A2UIMessage {
        if let version = json["version"] as? String {
            guard version == "v0.9" || version == "v0.8" else {
                throw A2UIValidationError(
                    message: "Unsupported A2UI protocol version: \(version). Expected v0.8 or v0.9."
                )
            }
        }

        // v0.9 canonical keys
        if let data = json["createSurface"] as? JsonMap {
            return .createSurface(try CreateSurfacePayload.fromJSON(data))
        }
        if let data = json["updateComponents"] as? JsonMap {
            return .updateComponents(try UpdateComponentsPayload.fromJSON(data))
        }
        if let data = json["updateDataModel"] as? JsonMap {
            return .updateDataModel(try UpdateDataModelPayload.fromJSON(data))
        }
        if let data = json["deleteSurface"] as? JsonMap {
            guard let sid = data[surfaceIdKey] as? String else {
                throw A2UIValidationError(message: "deleteSurface missing surfaceId")
            }
            return .deleteSurface(surfaceId: sid)
        }

        // v0.8 legacy keys — convert to v0.9
        if A2UIMessageV08Adapter.isV08Message(json) {
            return try A2UIMessageV08Adapter.convert(json)
        }

        throw A2UIValidationError(
            message: "Unknown A2UI message type. Expected one of: createSurface, "
                   + "updateComponents, updateDataModel, deleteSurface. Got: \(Array(json.keys))"
        )
    }
}

// MARK: - v0.9 Payloads

/// Payload for `createSurface` — starts a new surface or reconfigures an existing one.
public struct CreateSurfacePayload {
    public let surfaceId: String
    public let catalogId: String
    public let rootComponentId: String?
    public let theme: JsonMap?

    public init(
        surfaceId: String,
        catalogId: String = basicCatalogId,
        rootComponentId: String? = nil,
        theme: JsonMap? = nil
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.rootComponentId = rootComponentId
        self.theme = theme
    }

    public static func fromJSON(_ json: JsonMap) throws -> CreateSurfacePayload {
        guard let surfaceId = json[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "createSurface missing surfaceId")
        }
        return CreateSurfacePayload(
            surfaceId: surfaceId,
            catalogId: json["catalogId"] as? String ?? basicCatalogId,
            rootComponentId: json["rootComponentId"] as? String ?? json["root"] as? String,
            theme: json["theme"] as? JsonMap ?? json["styles"] as? JsonMap
        )
    }
}

/// Payload for `updateComponents` — delivers components to a surface.
public struct UpdateComponentsPayload {
    public let surfaceId: String
    public let components: [Component]

    public init(surfaceId: String, components: [Component]) {
        self.surfaceId = surfaceId
        self.components = components
    }

    public static func fromJSON(_ json: JsonMap) throws -> UpdateComponentsPayload {
        guard let surfaceId = json[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "updateComponents missing surfaceId")
        }
        guard let rawComponents = json["components"] as? [JsonMap] else {
            throw A2UIValidationError(message: "updateComponents missing components array")
        }
        let components = try rawComponents.map { raw -> Component in
            // v0.9 flat: "component" is a String
            if raw["component"] is String {
                return try Component.fromJSON(raw)
            }
            // v0.8 nested: "component" is a JsonMap
            return try Component.fromV08JSON(raw)
        }
        return UpdateComponentsPayload(surfaceId: surfaceId, components: components)
    }
}

/// Payload for `updateDataModel` — delivers data to a surface's data model.
public struct UpdateDataModelPayload {
    public let surfaceId: String
    public let path: DataPath
    public let value: Any?

    public init(surfaceId: String, path: DataPath = .root, value: Any? = nil) {
        self.surfaceId = surfaceId
        self.path = path
        self.value = value
    }

    public static func fromJSON(_ json: JsonMap) throws -> UpdateDataModelPayload {
        guard let surfaceId = json[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "updateDataModel missing surfaceId")
        }
        let pathStr = json["path"] as? String ?? "/"
        let value: Any? = json["value"]
        return UpdateDataModelPayload(
            surfaceId: surfaceId,
            path: DataPath(pathStr),
            value: value
        )
    }
}

// MARK: - v0.8 Data Conversion Utilities

/// Conversion utilities for v0.8 data formats (BoundValues, children, actions, contents).
public enum V08DataConverter {

    /// Converts v0.8 BoundValue objects to flat values.
    public static func convertBoundValue(_ map: JsonMap) -> Any {
        if map["path"] != nil {
            return map.filter { $0.key == "path" }
        }
        if let str = map["literalString"] as? String { return str }
        if let num = map["literalNumber"] { return num }
        if let bool = map["literalBoolean"] { return bool }
        if let arr = map["literalArray"] { return arr }
        return map
    }

    /// Converts v0.8 children format to flat array or template.
    public static func convertChildren(_ value: Any) -> Any {
        if let list = value as? [String] { return list }
        guard let map = value as? JsonMap else { return value }
        if let explicitList = map["explicitList"] as? [String] { return explicitList }
        if let template = map["template"] as? JsonMap {
            var result = JsonMap()
            result["componentId"] = template["componentId"]
            result["path"] = template["dataBinding"] ?? template["path"]
            return result
        }
        return value
    }

    /// Converts v0.8 action format.
    ///
    /// v0.8 action: `{"name": "submit", "context": [{"key": "id", "value": {...}}]}`
    /// v0.9 action: `{"event": {"name": "submit", "context": {"id": "..."}}}`
    ///
    /// If the action already has an `"event"` key (v0.9 format), it is returned as-is.
    public static func convertAction(_ value: Any) -> Any {
        guard var actionMap = value as? JsonMap else { return value }

        // Already v0.9 format
        if actionMap["event"] != nil { return actionMap }

        // Convert v0.8 context array to map
        if let contextArray = actionMap["context"] as? [JsonMap] {
            var contextMap = JsonMap()
            for entry in contextArray {
                if let key = entry["key"] as? String, let val = entry["value"] {
                    contextMap[key] = (val as? JsonMap).map { convertBoundValue($0) } ?? val
                }
            }
            actionMap["context"] = contextMap
        }

        // Wrap in "event" key (v0.9 format)
        return ["event": actionMap] as JsonMap
    }

    /// Recursively converts v0.8 component properties.
    public static func convertComponentProperties(_ props: JsonMap) -> JsonMap {
        var result = JsonMap()
        for (key, value) in props {
            if key == "children" {
                result[key] = convertChildren(value)
            } else if key == "action" {
                result[key] = convertAction(value)
            } else if let boundValue = value as? JsonMap {
                result[key] = convertBoundValue(boundValue)
            } else {
                result[key] = value
            }
        }
        if let primary = result["primary"] as? Bool, primary, result["variant"] == nil {
            result["variant"] = "primary"
            result.removeValue(forKey: "primary")
        }
        return result
    }

    /// v0.8 -> internal property name mapping.
    private static let propertyNameMap: [String: String] = [
        "usageHint": "variant",
        "distribution": "justify",
        "alignment": "align",
        "entryPointChild": "trigger",
        "contentChild": "content",
        "tabItems": "tabs",
        "textFieldType": "variant",
        "validationRegexp": "checks",
        "maxAllowedSelections": "",
    ]

    /// Renames v0.8 property names to internal equivalents.
    public static func remapPropertyNames(_ properties: JsonMap) -> JsonMap {
        var result = JsonMap()
        for (key, value) in properties {
            if let newKey = propertyNameMap[key] {
                if newKey.isEmpty { continue }
                result[newKey] = value
            } else {
                result[key] = value
            }
        }
        return result
    }

    /// Converts v0.8 adjacency-list `contents` to a standard JSON dictionary.
    public static func convertContentsToValue(_ contents: [JsonMap]) -> JsonMap {
        var result = JsonMap()
        for entry in contents {
            guard let key = entry["key"] as? String else { continue }
            if let str = entry["valueString"] as? String {
                result[key] = str
            } else if let num = entry["valueNumber"] {
                result[key] = num
            } else if let bool = entry["valueBoolean"] as? Bool {
                result[key] = bool
            } else if let nestedContents = entry["valueMap"] as? [JsonMap] {
                result[key] = convertContentsToValue(nestedContents)
            } else if let val = entry["value"] {
                result[key] = val
            }
        }
        return result
    }
}
