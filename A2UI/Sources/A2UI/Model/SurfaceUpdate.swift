import Foundation

/// Events emitted when surface state changes.
public enum SurfaceUpdate {
    /// A new surface was created.
    case surfaceAdded(surfaceId: String, definition: SurfaceDefinition)

    /// An existing surface's components were updated.
    case componentsUpdated(surfaceId: String, definition: SurfaceDefinition)

    /// A surface was removed.
    case surfaceRemoved(surfaceId: String)

    /// The surface ID associated with this update.
    public var surfaceId: String {
        switch self {
        case .surfaceAdded(let id, _): return id
        case .componentsUpdated(let id, _): return id
        case .surfaceRemoved(let id): return id
        }
    }
}
