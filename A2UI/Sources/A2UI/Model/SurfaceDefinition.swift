import Foundation

/// The complete UI definition for a single surface.
///
/// Holds all component definitions in a flat id-keyed map. Rendering starts
/// from the component whose id matches `rootComponentId` (defaults to `"root"`).
public final class SurfaceDefinition {

    /// The unique identifier of this surface.
    public let surfaceId: String

    /// Which catalog to use for rendering (defaults to `basicCatalogId`).
    public private(set) var catalogId: String

    /// All component definitions, keyed by component id.
    public private(set) var components: [String: Component]

    /// Optional theme parameters for this surface.
    public private(set) var theme: JsonMap?

    /// The ID of the root component for rendering. Defaults to `"root"` (v0.9 convention).
    /// In v0.8 this can be any component ID specified by `beginRendering.root`.
    public private(set) var rootComponentId: String

    public init(
        surfaceId: String,
        catalogId: String = basicCatalogId,
        components: [String: Component] = [:],
        theme: JsonMap? = nil,
        rootComponentId: String = "root"
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.components = components
        self.theme = theme
        self.rootComponentId = rootComponentId
    }

    /// Returns a copy with optionally replaced fields.
    public func copy(
        catalogId: String? = nil,
        components: [String: Component]? = nil,
        theme: JsonMap? = nil,
        rootComponentId: String? = nil
    ) -> SurfaceDefinition {
        SurfaceDefinition(
            surfaceId: surfaceId,
            catalogId: catalogId ?? self.catalogId,
            components: components ?? self.components,
            theme: theme ?? self.theme,
            rootComponentId: rootComponentId ?? self.rootComponentId
        )
    }
}
