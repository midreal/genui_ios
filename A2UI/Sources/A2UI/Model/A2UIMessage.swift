import Foundation

/// A message in the A2UI protocol stream (v0.9).
///
/// Each message must contain `"version": "v0.9"` and exactly one action key:
/// `createSurface`, `updateComponents`, `updateDataModel`, or `deleteSurface`.
public enum A2UIMessage {
    case createSurface(CreateSurfacePayload)
    case updateComponents(UpdateComponentsPayload)
    case updateDataModel(UpdateDataModelPayload)
    case deleteSurface(surfaceId: String)

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
    public static func fromJSON(_ json: JsonMap) throws -> A2UIMessage {
        guard let version = json["version"] as? String, version == a2uiProtocolVersion else {
            throw A2UIValidationError(
                message: "A2UI message must have version \"\(a2uiProtocolVersion)\""
            )
        }

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

        throw A2UIValidationError(message: "Unknown A2UI message type: \(Array(json.keys))")
    }
}

// MARK: - Payloads

public struct CreateSurfacePayload {
    public let surfaceId: String
    public let catalogId: String
    public let theme: JsonMap?
    public let sendDataModel: Bool

    public init(surfaceId: String, catalogId: String, theme: JsonMap? = nil, sendDataModel: Bool = false) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.theme = theme
        self.sendDataModel = sendDataModel
    }

    public static func fromJSON(_ json: JsonMap) throws -> CreateSurfacePayload {
        guard let surfaceId = json[surfaceIdKey] as? String else {
            throw A2UIValidationError(message: "createSurface missing surfaceId")
        }
        guard let catalogId = json["catalogId"] as? String else {
            throw A2UIValidationError(message: "createSurface missing catalogId")
        }
        return CreateSurfacePayload(
            surfaceId: surfaceId,
            catalogId: catalogId,
            theme: json["theme"] as? JsonMap,
            sendDataModel: json["sendDataModel"] as? Bool ?? false
        )
    }
}

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
        let components = try rawComponents.map { try Component.fromJSON($0) }
        return UpdateComponentsPayload(surfaceId: surfaceId, components: components)
    }
}

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
        return UpdateDataModelPayload(
            surfaceId: surfaceId,
            path: DataPath(pathStr),
            value: json["value"]
        )
    }
}
