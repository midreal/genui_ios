import UIKit
import Combine

/// The core rendering container that dynamically builds a UIView tree
/// from a `SurfaceDefinition`.
///
/// Subscribes to definition changes via `SurfaceContext` and recursively
/// rebuilds the view hierarchy starting from the `"root"` component.
public final class SurfaceView: UIView {

    /// The surface context providing definition, data model, and catalog.
    public let surfaceContext: SurfaceContext

    /// The delegate for intercepting UI events locally.
    public weak var actionDelegate: ActionDelegate?

    private var cancellable: AnyCancellable?
    private var currentContentView: UIView?

    public init(surfaceContext: SurfaceContext, actionDelegate: ActionDelegate? = nil) {
        self.surfaceContext = surfaceContext
        self.actionDelegate = actionDelegate
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setup() {
        backgroundColor = .clear
        cancellable = surfaceContext.definition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] definition in
                self?.rebuildUI(definition: definition)
            }
    }

    // MARK: - Rebuild

    private func rebuildUI(definition: SurfaceDefinition?) {
        currentContentView?.removeFromSuperview()
        currentContentView = nil

        guard let definition = definition else { return }
        guard definition.components.keys.contains("root") else { return }
        guard let catalog = surfaceContext.catalog else {
            let errorLabel = UILabel()
            errorLabel.text = "Catalog not found: \(definition.catalogId)"
            errorLabel.textColor = .systemRed
            embed(errorLabel)
            return
        }

        let rootDataContext = DataContext(
            dataModel: surfaceContext.dataModel,
            path: .root,
            functions: catalog.functions
        )

        let rootView = buildView(
            definition: definition,
            catalog: catalog,
            widgetId: "root",
            dataContext: rootDataContext
        )
        embed(rootView)
    }

    // MARK: - Recursive View Building

    /// Recursively builds a UIView for the given component id.
    public func buildView(
        definition: SurfaceDefinition,
        catalog: Catalog,
        widgetId: String,
        dataContext: DataContext
    ) -> UIView {
        guard let component = definition.components[widgetId] else {
            return makeFallbackView(message: "Component '\(widgetId)' not found")
        }

        let context = CatalogItemContext(
            id: widgetId,
            type: component.type,
            data: component.properties,
            buildChild: { [weak self] childId, childCtx in
                guard let self = self else { return UIView() }
                return self.buildView(
                    definition: definition,
                    catalog: catalog,
                    widgetId: childId,
                    dataContext: childCtx ?? dataContext
                )
            },
            dispatchEvent: { [weak self] event in
                self?.dispatchEvent(event)
            },
            dataContext: dataContext,
            getComponent: { definition.components[$0] },
            getCatalogItem: { catalog.item(named: $0) },
            surfaceId: surfaceContext.surfaceId,
            reportError: { [weak self] error in
                self?.surfaceContext.reportError(error)
            }
        )

        return catalog.buildView(context: context)
    }

    // MARK: - Event Dispatch

    private func dispatchEvent(_ event: UiEvent) {
        if let delegate = actionDelegate,
           let definition = surfaceContext.catalog != nil
                ? (try? currentDefinition())
                : nil,
           let catalog = surfaceContext.catalog {
            let handled = delegate.handleEvent(
                event,
                surfaceContext: surfaceContext,
                buildView: { [weak self] def, cat, id, ctx in
                    self?.buildView(definition: def, catalog: cat, widgetId: id, dataContext: ctx) ?? UIView()
                }
            )
            if handled { return }
        }

        var actionEvent = UserActionEvent(data: event.data)
        actionEvent.surfaceId = surfaceContext.surfaceId
        surfaceContext.handleUiEvent(actionEvent)
    }

    private func currentDefinition() throws -> SurfaceDefinition? {
        nil
    }

    // MARK: - Layout Helpers

    private func embed(_ view: UIView) {
        currentContentView = view
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func makeFallbackView(message: String) -> UIView {
        let label = UILabel()
        label.text = message
        label.textColor = .systemRed
        label.font = .systemFont(ofSize: 11)
        label.numberOfLines = 0
        return label
    }
}
