import Foundation

/// Converts A2UI v0.8 messages to the internal v0.9 model.
///
/// v0.8 (stable) uses different message names, component formats, and data model
/// structure compared to v0.9 (draft). This adapter bridges the gap so both
/// protocol versions can be processed by the same engine.
///
/// Key differences handled:
/// - Message types: `beginRendering` -> `createSurface`, `surfaceUpdate` -> `updateComponents`,
///   `dataModelUpdate` -> `updateDataModel`
/// - Component format: nested key-based `{"Text": {...}}` -> flat discriminator `"component": "Text"`
/// - Data model: adjacency list `contents` -> standard JSON `value`
/// - Data binding: `literalString`/`literalNumber` -> direct values
/// - Property renames: `usageHint` -> `variant`, `distribution` -> `justify`, etc.
public enum A2UIMessageV08Adapter {

    /// The set of top-level keys that identify a v0.8 message.
    static let v08MessageKeys: Set<String> = [
        "beginRendering", "surfaceUpdate", "dataModelUpdate", "deleteSurface"
    ]

    /// Returns `true` if the JSON appears to be a v0.8 message (no `version` field,
    /// contains a recognized v0.8 action key).
    public static func isV08Message(_ json: JsonMap) -> Bool {
        json["version"] == nil && !json.keys.filter({ v08MessageKeys.contains($0) }).isEmpty
    }

    /// Converts a v0.8 JSON message to an `A2UIMessage` (internal v0.9 model).
    public static func convert(_ json: JsonMap) throws -> A2UIMessage {
        if let data = json["beginRendering"] as? JsonMap {
            return try convertBeginRendering(data)
        }
        if let data = json["surfaceUpdate"] as? JsonMap {
            return try convertSurfaceUpdate(data)
        }
        if let data = json["dataModelUpdate"] as? JsonMap {
            return try convertDataModelUpdate(data)
        }
        if let data = json["deleteSurface"] as? JsonMap {
            guard let sid = data[surfaceIdKey] as? String else {
                throw A2UIValidationError(message: "v0.8 deleteSurface missing surfaceId")
            }
            return .deleteSurface(surfaceId: sid)
        }
        throw A2UIValidationError(message: "Unknown v0.8 message type: \(Array(json.keys))")
    }

    // MARK: - beginRendering -> createSurface

    private static func convertBeginRendering(_ json: JsonMap) throws -> A2UIMessage {
        guard let surfaceId = json[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "v0.8 beginRendering missing surfaceId")
        }
        let catalogId = json["catalogId"] as? String ?? basicCatalogId
        let theme = json["styles"] as? JsonMap ?? json["theme"] as? JsonMap
        let rootId = json["root"] as? String
        let sendDataModel = json["sendDataModel"] as? Bool ?? false

        let payload = CreateSurfacePayload(
            surfaceId: surfaceId,
            catalogId: catalogId,
            theme: theme,
            sendDataModel: sendDataModel,
            rootComponentId: rootId
        )
        return .createSurface(payload)
    }

    // MARK: - surfaceUpdate -> updateComponents

    private static func convertSurfaceUpdate(_ json: JsonMap) throws -> A2UIMessage {
        guard let surfaceId = json[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "v0.8 surfaceUpdate missing surfaceId")
        }
        guard let rawComponents = json["components"] as? [JsonMap] else {
            throw A2UIValidationError(message: "v0.8 surfaceUpdate missing components array")
        }
        let components = try rawComponents.map { try convertComponent($0) }
        return .updateComponents(UpdateComponentsPayload(surfaceId: surfaceId, components: components))
    }

    // MARK: - dataModelUpdate -> updateDataModel

    private static func convertDataModelUpdate(_ json: JsonMap) throws -> A2UIMessage {
        guard let surfaceId = json[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "v0.8 dataModelUpdate missing surfaceId")
        }
        let pathStr = json["path"] as? String ?? "/"

        let value: Any?
        if let contents = json["contents"] as? [JsonMap] {
            value = convertContentsToValue(contents)
        } else if let directValue = json["value"] {
            value = directValue
        } else {
            value = nil
        }

        return .updateDataModel(UpdateDataModelPayload(
            surfaceId: surfaceId,
            path: DataPath(pathStr),
            value: value
        ))
    }

    // MARK: - Component Conversion

    /// Converts a v0.8 component (nested key-based) to a v0.9 component (flat discriminator).
    ///
    /// v0.8: `{"id": "t1", "component": {"Text": {"text": {"literalString": "Hi"}, "usageHint": "h2"}}}`
    /// v0.9: `{"id": "t1", "component": "Text", "text": "Hi", "variant": "h2"}`
    public static func convertComponent(_ json: JsonMap) throws -> Component {
        guard let id = json["id"] as? String else {
            throw A2UIValidationError(message: "v0.8 component missing 'id'")
        }

        guard let componentWrapper = json["component"] else {
            throw A2UIValidationError(message: "v0.8 component missing 'component' field")
        }

        // v0.9 style: "component" is already a string discriminator
        if let typeName = componentWrapper as? String {
            var properties = json
            properties.removeValue(forKey: "id")
            properties.removeValue(forKey: "component")
            let remapped = remapPropertyNames(properties)
            return Component(id: id, type: typeName, properties: remapped)
        }

        // v0.8 style: "component" is a dict like {"Text": {"text": ...}}
        guard let componentMap = componentWrapper as? JsonMap,
              let typeName = componentMap.keys.first,
              let innerProps = componentMap[typeName] as? JsonMap else {
            throw A2UIValidationError(message: "v0.8 component has invalid 'component' structure")
        }

        var properties = convertComponentProperties(innerProps)
        properties = remapPropertyNames(properties)

        return Component(id: id, type: typeName, properties: properties)
    }

    /// Recursively converts v0.8 component properties to v0.9 format.
    private static func convertComponentProperties(_ props: JsonMap) -> JsonMap {
        var result = JsonMap()
        for (key, value) in props {
            result[key] = convertPropertyValue(value, key: key)
        }

        if let primary = result["primary"] as? Bool, primary, result["variant"] == nil {
            result["variant"] = "primary"
            result.removeValue(forKey: "primary")
        }

        return result
    }

    /// Converts a single property value, handling BoundValue objects and children.
    private static func convertPropertyValue(_ value: Any, key: String) -> Any {
        if key == "children" {
            return convertChildren(value)
        }
        if key == "action" {
            return convertAction(value)
        }
        if let boundValue = value as? JsonMap {
            return convertBoundValue(boundValue)
        }
        return value
    }

    // MARK: - BoundValue Conversion

    /// Converts v0.8 BoundValue objects to v0.9 format.
    ///
    /// v0.8: `{"literalString": "Hello"}` -> v0.9: `"Hello"`
    /// v0.8: `{"literalNumber": 42}` -> v0.9: `42`
    /// v0.8: `{"literalBoolean": true}` -> v0.9: `true`
    /// v0.8: `{"path": "/x"}` -> v0.9: `{"path": "/x"}` (unchanged)
    /// v0.8: `{"path": "/x", "literalString": "default"}` -> v0.9: `{"path": "/x"}` (path takes priority)
    public static func convertBoundValue(_ map: JsonMap) -> Any {
        // If it has a path, keep as path object (v0.9 format)
        if map["path"] != nil {
            return map.filter { $0.key == "path" }
        }

        if let str = map["literalString"] as? String {
            return str
        }
        if let num = map["literalNumber"] {
            return num
        }
        if let bool = map["literalBoolean"] {
            return bool
        }
        if let arr = map["literalArray"] {
            return arr
        }

        // Not a recognized BoundValue — return as-is (could be a nested object)
        return map
    }

    // MARK: - Children Conversion

    /// Converts v0.8 children format to v0.9 format.
    ///
    /// v0.8: `{"explicitList": ["a", "b"]}` -> v0.9: `["a", "b"]`
    /// v0.8: `{"template": {"componentId": "x", "dataBinding": "/y"}}` -> v0.9: `{"componentId": "x", "path": "/y"}`
    public static func convertChildren(_ value: Any) -> Any {
        if let list = value as? [String] {
            return list
        }

        guard let map = value as? JsonMap else {
            return value
        }

        if let explicitList = map["explicitList"] as? [String] {
            return explicitList
        }

        if let template = map["template"] as? JsonMap {
            var result = JsonMap()
            result["componentId"] = template["componentId"]
            result["path"] = template["dataBinding"] ?? template["path"]
            return result
        }

        return value
    }

    // MARK: - Action Conversion

    /// Converts v0.8 action format to v0.9 format.
    ///
    /// v0.8 context uses array of key-value pairs:
    /// `[{"key": "id", "value": {"literalString": "123"}}]`
    /// v0.9 context uses a standard map:
    /// `{"id": "123"}`
    public static func convertAction(_ value: Any) -> Any {
        guard var actionMap = value as? JsonMap else { return value }

        // Convert context array to map
        if let contextArray = actionMap["context"] as? [JsonMap] {
            var contextMap = JsonMap()
            for entry in contextArray {
                if let key = entry["key"] as? String, let val = entry["value"] {
                    if let boundVal = val as? JsonMap {
                        contextMap[key] = convertBoundValue(boundVal)
                    } else {
                        contextMap[key] = val
                    }
                }
            }
            actionMap["context"] = contextMap
        }

        // Rename "name" -> wrap in "event" if not already
        if actionMap["event"] == nil, let name = actionMap["name"] as? String {
            var event = JsonMap()
            event["name"] = name
            if let context = actionMap["context"] {
                event["context"] = context
            }
            actionMap = ["event": event]
        }

        return actionMap
    }

    // MARK: - Property Name Remapping

    /// v0.8 -> v0.9 property name changes.
    private static let propertyNameMap: [String: String] = [
        "usageHint": "variant",
        "distribution": "justify",
        "alignment": "align",
        "entryPointChild": "trigger",
        "contentChild": "content",
        "tabItems": "tabs",
        "textFieldType": "variant",
        "validationRegexp": "checks",
        "maxAllowedSelections": "",   // removed in v0.9
    ]

    /// Renames v0.8 property names to their v0.9 equivalents.
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

    // MARK: - Data Contents Conversion

    /// Converts v0.8 adjacency-list `contents` to a standard JSON dictionary.
    ///
    /// v0.8: `[{"key": "name", "valueString": "Alice"}, {"key": "age", "valueNumber": 30}]`
    /// v0.9: `{"name": "Alice", "age": 30}`
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
