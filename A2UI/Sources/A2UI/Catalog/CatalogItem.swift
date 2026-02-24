import UIKit

/// The builder function signature for creating a UIView from component context.
public typealias CatalogViewBuilder = (CatalogItemContext) -> UIView

/// Callback to build a child component by its id.
public typealias ChildBuilderCallback = (String, DataContext?) -> UIView

/// Callback to dispatch a UI event.
public typealias DispatchEventCallback = (UiEvent) -> Void

/// Defines a single UI component type: its name, and how to build its view.
public struct CatalogItem {

    /// The component type name (matches the `"component"` field in JSON).
    public let name: String

    /// Whether this component should be implicitly flexible in Row/Column containers.
    public let isImplicitlyFlexible: Bool

    /// The view builder function.
    public let viewBuilder: CatalogViewBuilder

    public init(
        name: String,
        isImplicitlyFlexible: Bool = false,
        viewBuilder: @escaping CatalogViewBuilder
    ) {
        self.name = name
        self.isImplicitlyFlexible = isImplicitlyFlexible
        self.viewBuilder = viewBuilder
    }
}

/// Context provided to a `CatalogItem`'s view builder.
///
/// Encapsulates all information and callbacks needed to build a component view,
/// including access to properties, child building, event dispatch, and data binding.
public struct CatalogItemContext {

    /// The unique identifier for this component instance.
    public let id: String

    /// The component type name.
    public let type: String

    /// The component's properties (JSON keys minus `id` and `component`).
    public let data: JsonMap

    /// Callback to recursively build a child component by its id.
    public let buildChild: ChildBuilderCallback

    /// Callback to dispatch user interaction events.
    public let dispatchEvent: DispatchEventCallback

    /// The data context for reactive data binding.
    public let dataContext: DataContext

    /// Callback to look up a component definition by its id.
    public let getComponent: (String) -> Component?

    /// Callback to look up a catalog item by its type name.
    public let getCatalogItem: (String) -> CatalogItem?

    /// The surface ID this component belongs to.
    public let surfaceId: String

    /// Callback to report an error from this component.
    public let reportError: (Error) -> Void

    public init(
        id: String,
        type: String,
        data: JsonMap,
        buildChild: @escaping ChildBuilderCallback,
        dispatchEvent: @escaping DispatchEventCallback,
        dataContext: DataContext,
        getComponent: @escaping (String) -> Component?,
        getCatalogItem: @escaping (String) -> CatalogItem?,
        surfaceId: String,
        reportError: @escaping (Error) -> Void
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.buildChild = buildChild
        self.dispatchEvent = dispatchEvent
        self.dataContext = dataContext
        self.getComponent = getComponent
        self.getCatalogItem = getCatalogItem
        self.surfaceId = surfaceId
        self.reportError = reportError
    }
}
