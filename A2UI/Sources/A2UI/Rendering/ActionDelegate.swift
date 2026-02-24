import UIKit

/// Delegate protocol for intercepting UI events before they are sent to the server.
///
/// Implement this to handle local-only actions such as showing modals,
/// navigation, or other client-side operations.
public protocol ActionDelegate: AnyObject {
    /// Handles a UI event. Returns `true` if the event was consumed locally.
    ///
    /// - Parameters:
    ///   - event: The user interaction event.
    ///   - surfaceContext: The context of the surface that produced the event.
    ///   - buildView: A closure to build a sub-view tree (useful for modals).
    /// - Returns: `true` if the event was handled and should NOT be forwarded to the server.
    func handleEvent(
        _ event: UiEvent,
        surfaceContext: SurfaceContext,
        buildView: @escaping (SurfaceDefinition, Catalog, String, DataContext) -> UIView
    ) -> Bool
}

/// Default action delegate that does not handle any events.
public final class DefaultActionDelegate: ActionDelegate {
    public init() {}

    public func handleEvent(
        _ event: UiEvent,
        surfaceContext: SurfaceContext,
        buildView: @escaping (SurfaceDefinition, Catalog, String, DataContext) -> UIView
    ) -> Bool {
        false
    }
}
