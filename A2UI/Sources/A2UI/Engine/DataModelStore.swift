import Foundation

/// Manages per-surface `DataModel` instances.
///
/// Each surface gets its own isolated data model. Surfaces can optionally
/// be "attached" to signal that the full data model should be sent back
/// to the server.
public final class DataModelStore {

    private var dataModels: [String: DataModelProtocol] = [:]
    private var attachedSurfaces: Set<String> = []

    public init() {}

    /// Returns the data model for the given surface, creating one if needed.
    public func getDataModel(surfaceId: String) -> DataModelProtocol {
        if let existing = dataModels[surfaceId] {
            return existing
        }
        let model = InMemoryDataModel()
        dataModels[surfaceId] = model
        return model
    }

    /// Removes and disposes the data model for the given surface.
    public func removeDataModel(surfaceId: String) {
        dataModels[surfaceId]?.dispose()
        dataModels.removeValue(forKey: surfaceId)
        attachedSurfaces.remove(surfaceId)
    }

    /// Marks a surface as "attached" (sendDataModel = true).
    public func attachSurface(_ surfaceId: String) {
        attachedSurfaces.insert(surfaceId)
    }

    /// Marks a surface as "detached".
    public func detachSurface(_ surfaceId: String) {
        attachedSurfaces.remove(surfaceId)
    }

    /// Whether the given surface is attached.
    public func isAttached(_ surfaceId: String) -> Bool {
        attachedSurfaces.contains(surfaceId)
    }

    /// Disposes of all data models.
    public func dispose() {
        for model in dataModels.values {
            model.dispose()
        }
        dataModels.removeAll()
        attachedSurfaces.removeAll()
    }
}
