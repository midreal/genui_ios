import Foundation
import Combine

/// The runtime controller for the A2UI system.
///
/// Orchestrates surface lifecycle, message handling, data model management,
/// and user interaction event routing. This is the central hub of the framework.
public final class SurfaceController {

    /// Available component catalogs.
    public let catalogs: [Catalog]

    /// How long to buffer messages for a surface that hasn't been created yet.
    public let pendingUpdateTimeout: TimeInterval

    /// The surface registry managed by this controller.
    public let registry = SurfaceRegistry()

    /// The data model store managed by this controller.
    public let store = DataModelStore()

    /// User interaction events to be sent back to the server.
    public let onSubmit = PassthroughSubject<UserActionEvent, Never>()

    /// Surface update events.
    public var surfaceUpdates: AnyPublisher<SurfaceUpdate, Never> {
        registry.events
    }

    /// The IDs of currently active surfaces.
    public var activeSurfaceIds: [String] {
        registry.activeSurfaceIds
    }

    private var pendingUpdates: [String: [A2UIMessage]] = [:]
    private var pendingTimers: [String: DispatchWorkItem] = [:]

    public init(catalogs: [Catalog], pendingUpdateTimeout: TimeInterval = 60) {
        self.catalogs = catalogs
        self.pendingUpdateTimeout = pendingUpdateTimeout
    }

    // MARK: - Message Handling

    /// Processes an incoming A2UI message.
    public func handleMessage(_ message: A2UIMessage) {
        do {
            try handleMessageInternal(message)
        } catch let error as A2UIValidationError {
            reportError(error)
        } catch {
            reportError(A2UIValidationError(message: error.localizedDescription))
        }
    }

    private func handleMessageInternal(_ message: A2UIMessage) throws {
        switch message {
        case .createSurface(let payload):
            try handleCreateSurface(payload)

        case .updateComponents(let payload):
            try handleUpdateComponents(payload)

        case .updateDataModel(let payload):
            handleUpdateDataModel(payload)

        case .deleteSurface(let surfaceId):
            handleDeleteSurface(surfaceId)
        }
    }

    // MARK: - Create Surface

    private func handleCreateSurface(_ payload: CreateSurfacePayload) throws {
        let surfaceId = payload.surfaceId
        guard !surfaceId.isEmpty else {
            throw A2UIValidationError(message: "Surface ID cannot be empty", surfaceId: surfaceId)
        }

        let pending = pendingUpdates.removeValue(forKey: surfaceId) ?? []
        pendingTimers[surfaceId]?.cancel()
        pendingTimers.removeValue(forKey: surfaceId)

        _ = store.getDataModel(surfaceId: surfaceId)

        let existing = registry.getSurface(id: surfaceId)
        let definition = (existing ?? SurfaceDefinition(surfaceId: surfaceId)).copy(
            catalogId: payload.catalogId,
            theme: payload.theme,
            rootComponentId: payload.rootComponentId
        )

        registry.updateSurface(id: surfaceId, definition: definition, isNew: existing == nil)

        for msg in pending {
            try handleMessageInternal(msg)
        }
    }

    // MARK: - Update Components

    private func handleUpdateComponents(_ payload: UpdateComponentsPayload) throws {
        let surfaceId = payload.surfaceId
        guard registry.hasSurface(id: surfaceId) else {
            bufferMessage(.updateComponents(payload), surfaceId: surfaceId)
            return
        }

        guard let current = registry.getSurface(id: surfaceId) else { return }
        var newComponents = current.components
        for component in payload.components {
            newComponents[component.id] = component
        }

        let updated = current.copy(components: newComponents)
        registry.updateSurface(id: surfaceId, definition: updated)
    }

    // MARK: - Update Data Model

    private func handleUpdateDataModel(_ payload: UpdateDataModelPayload) {
        let surfaceId = payload.surfaceId
        guard registry.hasSurface(id: surfaceId) else {
            bufferMessage(.updateDataModel(payload), surfaceId: surfaceId)
            return
        }

        let model = store.getDataModel(surfaceId: surfaceId)
        model.update(path: payload.path, value: payload.value)

        if let current = registry.getSurface(id: surfaceId) {
            registry.updateSurface(id: surfaceId, definition: current)
        }
    }

    // MARK: - Delete Surface

    private func handleDeleteSurface(_ surfaceId: String) {
        pendingUpdates.removeValue(forKey: surfaceId)
        pendingTimers[surfaceId]?.cancel()
        pendingTimers.removeValue(forKey: surfaceId)
        registry.removeSurface(id: surfaceId)
        store.removeDataModel(surfaceId: surfaceId)
    }

    // MARK: - Message Buffering

    private func bufferMessage(_ message: A2UIMessage, surfaceId: String) {
        pendingUpdates[surfaceId, default: []].append(message)

        if pendingTimers[surfaceId] == nil {
            let workItem = DispatchWorkItem { [weak self] in
                self?.pendingUpdates.removeValue(forKey: surfaceId)
                self?.pendingTimers.removeValue(forKey: surfaceId)
            }
            pendingTimers[surfaceId] = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + pendingUpdateTimeout, execute: workItem)
        }
    }

    // MARK: - UI Events

    /// Handles a user interaction event from a rendered surface.
    public func handleUiEvent(_ event: UserActionEvent) {
        onSubmit.send(event)
    }

    // MARK: - Error Reporting

    /// Reports an error back through the submit channel.
    public func reportError(_ error: A2UIValidationError) {
        let errorEvent = UserActionEvent(data: [
            "version": a2uiProtocolVersion,
            "error": [
                "code": "VALIDATION_FAILED",
                "surfaceId": error.surfaceId as Any,
                "path": error.path as Any,
                "message": error.message
            ] as JsonMap
        ])
        onSubmit.send(errorEvent)
    }

    // MARK: - Context

    /// Creates a `SurfaceContext` for the given surface, bridging the engine to the renderer.
    public func contextFor(surfaceId: String) -> SurfaceContext {
        ControllerSurfaceContext(controller: self, surfaceId: surfaceId)
    }

    /// Finds the catalog matching the given definition's catalogId.
    /// Falls back to the first registered catalog if no exact match is found.
    public func findCatalog(for definition: SurfaceDefinition) -> Catalog? {
        catalogs.first { $0.catalogId == definition.catalogId }
            ?? catalogs.first
    }

    // MARK: - Dispose

    /// Releases all resources.
    public func dispose() {
        registry.dispose()
        store.dispose()
        for timer in pendingTimers.values { timer.cancel() }
        pendingTimers.removeAll()
        pendingUpdates.removeAll()
    }
}

// MARK: - Internal SurfaceContext

private final class ControllerSurfaceContext: SurfaceContext {
    private let controller: SurfaceController
    let surfaceId: String

    init(controller: SurfaceController, surfaceId: String) {
        self.controller = controller
        self.surfaceId = surfaceId
    }

    var definition: AnyPublisher<SurfaceDefinition?, Never> {
        controller.registry.watchSurface(id: surfaceId)
    }

    var dataModel: DataModelProtocol {
        controller.store.getDataModel(surfaceId: surfaceId)
    }

    var catalog: Catalog? {
        guard let def = controller.registry.getSurface(id: surfaceId) else { return nil }
        return controller.findCatalog(for: def)
    }

    func handleUiEvent(_ event: UserActionEvent) {
        controller.handleUiEvent(event)
    }

    func reportError(_ error: Error) {
        let validationError = error as? A2UIValidationError
            ?? A2UIValidationError(message: error.localizedDescription, surfaceId: surfaceId)
        controller.reportError(validationError)
    }
}
