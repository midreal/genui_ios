import Foundation
import Combine

/// Manages the lifecycle and storage of `SurfaceDefinition` instances.
///
/// Each surface is backed by a `CurrentValueSubject` so that renderers
/// can subscribe to definition changes via Combine.
public final class SurfaceRegistry {

    private var surfaces: [String: CurrentValueSubject<SurfaceDefinition?, Never>] = [:]
    private var surfaceOrder: [String] = []
    private let eventsSubject = PassthroughSubject<SurfaceUpdate, Never>()

    public init() {}

    /// Stream of registry events (added / updated / removed).
    public var events: AnyPublisher<SurfaceUpdate, Never> {
        eventsSubject.eraseToAnyPublisher()
    }

    /// The IDs of active surfaces in creation/update order.
    public var activeSurfaceIds: [String] {
        surfaceOrder
    }

    /// Returns a publisher that tracks the definition of the surface with the given id.
    /// Lazily creates a subject if the surface hasn't been registered yet.
    public func watchSurface(id: String) -> AnyPublisher<SurfaceDefinition?, Never> {
        let subject = surfaces[id] ?? {
            let s = CurrentValueSubject<SurfaceDefinition?, Never>(nil)
            surfaces[id] = s
            return s
        }()
        return subject.eraseToAnyPublisher()
    }

    /// Returns the current definition for the given surface, or nil.
    public func getSurface(id: String) -> SurfaceDefinition? {
        surfaces[id]?.value
    }

    /// Returns whether a surface with the given id exists and has a non-nil definition.
    public func hasSurface(id: String) -> Bool {
        surfaces[id]?.value != nil
    }

    /// Updates the definition of a surface, emitting the appropriate event.
    public func updateSurface(id: String, definition: SurfaceDefinition, isNew: Bool = false) {
        let subject = surfaces[id] ?? {
            let s = CurrentValueSubject<SurfaceDefinition?, Never>(nil)
            surfaces[id] = s
            return s
        }()
        subject.send(definition)

        surfaceOrder.removeAll { $0 == id }
        surfaceOrder.append(id)

        if isNew {
            eventsSubject.send(.surfaceAdded(surfaceId: id, definition: definition))
        } else {
            eventsSubject.send(.componentsUpdated(surfaceId: id, definition: definition))
        }
    }

    /// Removes a surface from the registry.
    public func removeSurface(id: String) {
        guard surfaces[id] != nil else { return }
        surfaces[id]?.send(completion: .finished)
        surfaces.removeValue(forKey: id)
        surfaceOrder.removeAll { $0 == id }
        eventsSubject.send(.surfaceRemoved(surfaceId: id))
    }

    /// Disposes of all surfaces and closes the event stream.
    public func dispose() {
        for subject in surfaces.values {
            subject.send(completion: .finished)
        }
        surfaces.removeAll()
        surfaceOrder.removeAll()
        eventsSubject.send(completion: .finished)
    }
}
