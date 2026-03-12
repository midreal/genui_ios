import Foundation

/// Declares the client's UI rendering capabilities to the A2A server.
///
/// Sent with every outgoing message so the server knows which component
/// catalogs the client supports and can generate matching UI.
public struct A2UiClientCapabilities {

    /// Catalog IDs the client supports (e.g. "a2ui.org:standard_catalog_0_8_0").
    public let supportedCatalogIds: [String]

    /// Optional inline catalog definitions for custom components.
    public let inlineCatalogs: [JsonMap]?

    public init(supportedCatalogIds: [String], inlineCatalogs: [JsonMap]? = nil) {
        self.supportedCatalogIds = supportedCatalogIds
        self.inlineCatalogs = inlineCatalogs
    }

    /// Serializes to a JSON dictionary for embedding in message metadata.
    public func toJSON() -> JsonMap {
        var json: JsonMap = ["supportedCatalogIds": supportedCatalogIds]
        if let inlineCatalogs { json["inlineCatalogs"] = inlineCatalogs }
        return json
    }
}
