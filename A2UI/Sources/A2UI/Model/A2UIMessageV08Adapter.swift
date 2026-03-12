import Foundation

/// Adapter that converts v0.8 protocol messages to the v0.9 canonical format.
///
/// v0.8 used `beginRendering`, `surfaceUpdate`, `dataModelUpdate`.
/// v0.9 uses `createSurface`, `updateComponents`, `updateDataModel`.
public enum A2UIMessageV08Adapter {

    // MARK: - Detection

    /// Returns true if the JSON looks like a v0.8 message (has legacy keys, no `version` field).
    public static func isV08Message(_ json: JsonMap) -> Bool {
        guard json["version"] == nil else { return false }
        return json["beginRendering"] != nil
            || json["surfaceUpdate"] != nil
            || json["dataModelUpdate"] != nil
    }

    // MARK: - Conversion

    /// Converts a v0.8 JSON message to a v0.9 `A2UIMessage`.
    public static func convert(_ json: JsonMap) throws -> A2UIMessage {
        if let data = json["beginRendering"] as? JsonMap {
            return .createSurface(try convertBeginRendering(data))
        }
        if let data = json["surfaceUpdate"] as? JsonMap {
            return .updateComponents(try convertSurfaceUpdate(data))
        }
        if let data = json["dataModelUpdate"] as? JsonMap {
            return .updateDataModel(try convertDataModelUpdate(data))
        }
        if let data = json["deleteSurface"] as? JsonMap {
            guard let sid = data[surfaceIdKey] as? String else {
                throw A2UIValidationError(message: "deleteSurface missing surfaceId")
            }
            return .deleteSurface(surfaceId: sid)
        }
        throw A2UIValidationError(message: "Not a v0.8 message: \(Array(json.keys))")
    }

    private static func convertBeginRendering(_ data: JsonMap) throws -> CreateSurfacePayload {
        guard let surfaceId = data[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "beginRendering missing surfaceId")
        }
        return CreateSurfacePayload(
            surfaceId: surfaceId,
            catalogId: data["catalogId"] as? String ?? basicCatalogId,
            rootComponentId: data["root"] as? String,
            theme: data["styles"] as? JsonMap ?? data["theme"] as? JsonMap
        )
    }

    private static func convertSurfaceUpdate(_ data: JsonMap) throws -> UpdateComponentsPayload {
        guard let surfaceId = data[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "surfaceUpdate missing surfaceId")
        }
        guard let rawComponents = data["components"] as? [JsonMap] else {
            throw A2UIValidationError(message: "surfaceUpdate missing components array")
        }
        let components = try rawComponents.map { try Component.fromV08JSON($0) }
        return UpdateComponentsPayload(surfaceId: surfaceId, components: components)
    }

    private static func convertDataModelUpdate(_ data: JsonMap) throws -> UpdateDataModelPayload {
        guard let surfaceId = data[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "dataModelUpdate missing surfaceId")
        }
        let pathStr = data["path"] as? String ?? "/"

        let value: Any?
        if let contents = data["contents"] as? [JsonMap] {
            value = V08DataConverter.convertContentsToValue(contents)
        } else if let directValue = data["value"] {
            value = directValue
        } else {
            value = nil
        }

        return UpdateDataModelPayload(
            surfaceId: surfaceId,
            path: DataPath(pathStr),
            value: value
        )
    }

    // MARK: - Component Conversion

    /// Converts a single component from v0.8 JSON format.
    public static func convertComponent(_ json: JsonMap) throws -> Component {
        try Component.fromV08JSON(json)
    }

    // MARK: - Forwarding helpers (convenience access to V08DataConverter)

    public static func convertBoundValue(_ map: JsonMap) -> Any {
        V08DataConverter.convertBoundValue(map)
    }

    public static func convertChildren(_ value: Any) -> Any {
        V08DataConverter.convertChildren(value)
    }

    public static func remapPropertyNames(_ properties: JsonMap) -> JsonMap {
        V08DataConverter.remapPropertyNames(properties)
    }

    public static func convertAction(_ value: Any) -> Any {
        V08DataConverter.convertAction(value)
    }

    public static func convertContentsToValue(_ contents: [JsonMap]) -> JsonMap {
        V08DataConverter.convertContentsToValue(contents)
    }
}

// MARK: - v0.8 Component Parsing

extension Component {
    /// Parses a component from v0.8 JSON format.
    ///
    /// v0.8: `{"id": "t1", "component": {"Text": {"text": {"literalString": "Hi"}, "usageHint": "h2"}}}`
    public static func fromV08JSON(_ json: JsonMap) throws -> Component {
        guard let id = json["id"] as? String else {
            throw A2UIValidationError(message: "Component missing 'id'")
        }
        guard let componentWrapper = json["component"] else {
            throw A2UIValidationError(message: "Component missing 'component' field")
        }

        if let typeName = componentWrapper as? String {
            var properties = json
            properties.removeValue(forKey: "id")
            properties.removeValue(forKey: "component")
            return Component(id: id, type: typeName, properties: V08DataConverter.remapPropertyNames(properties))
        }

        guard let componentMap = componentWrapper as? JsonMap,
              let typeName = componentMap.keys.first,
              let innerProps = componentMap[typeName] as? JsonMap else {
            throw A2UIValidationError(message: "Component has invalid 'component' structure")
        }

        var properties = V08DataConverter.convertComponentProperties(innerProps)
        properties = V08DataConverter.remapPropertyNames(properties)
        return Component(id: id, type: typeName, properties: properties)
    }
}
