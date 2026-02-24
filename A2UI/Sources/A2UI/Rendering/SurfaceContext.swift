import Foundation
import Combine

/// Bridge protocol between the rendering layer (`SurfaceView`) and the engine layer.
///
/// Provides access to the surface definition, data model, catalog, and
/// event routing for a specific surface.
public protocol SurfaceContext: AnyObject {
    /// The unique identifier of this surface.
    var surfaceId: String { get }

    /// A publisher emitting the current surface definition (or nil if not yet created).
    var definition: AnyPublisher<SurfaceDefinition?, Never> { get }

    /// The data model for this surface.
    var dataModel: DataModelProtocol { get }

    /// The catalog to use for rendering this surface's components.
    var catalog: Catalog? { get }

    /// Routes a user action event from this surface back to the engine.
    func handleUiEvent(_ event: UserActionEvent)

    /// Reports an error that occurred during rendering.
    func reportError(_ error: Error)
}
