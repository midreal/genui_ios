import Foundation

/// A message in the A2UI protocol stream.
///
/// Supports both v0.9 (draft) and v0.8 (stable) protocol formats.
/// v0.9 messages must contain `"version": "v0.9"` and use `createSurface`/`updateComponents`/etc.
/// v0.8 messages have no `version` field and use `beginRendering`/`surfaceUpdate`/etc.
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
    ///
    /// Automatically detects the protocol version:
    /// - If `"version": "v0.9"` is present, parses as v0.9.
    /// - If no `version` field and v0.8 keys are found, parses as v0.8 via adapter.
    public static func fromJSON(_ json: JsonMap) throws -> A2UIMessage {
        if let version = json["version"] as? String {
            guard version == a2uiProtocolVersion else {
                throw A2UIValidationError(
                    message: "Unsupported A2UI version \"\(version)\", expected \"\(a2uiProtocolVersion)\""
                )
            }
            return try parseV09(json)
        }

        if A2UIMessageV08Adapter.isV08Message(json) {
            return try A2UIMessageV08Adapter.convert(json)
        }

        throw A2UIValidationError(
            message: "Unknown A2UI message format. Expected v0.9 (with version field) "
                   + "or v0.8 (beginRendering/surfaceUpdate/dataModelUpdate): \(Array(json.keys))"
        )
    }

    /// Parses a v0.9 format message (version field already validated).
    static func parseV09(_ json: JsonMap) throws -> A2UIMessage {
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

        throw A2UIValidationError(message: "Unknown A2UI v0.9 message type: \(Array(json.keys))")
    }
}

// MARK: - Payloads

public struct CreateSurfacePayload {
    public let surfaceId: String
    public let catalogId: String
    public let theme: JsonMap?
    public let sendDataModel: Bool
    /// The ID of the root component. In v0.9 this is always "root" by convention;
    /// in v0.8 it can be any component ID specified by `beginRendering.root`.
    public let rootComponentId: String?

    public init(
        surfaceId: String,
        catalogId: String,
        theme: JsonMap? = nil,
        sendDataModel: Bool = false,
        rootComponentId: String? = nil
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.theme = theme
        self.sendDataModel = sendDataModel
        self.rootComponentId = rootComponentId
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
            sendDataModel: json["sendDataModel"] as? Bool ?? false,
            rootComponentId: nil
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
