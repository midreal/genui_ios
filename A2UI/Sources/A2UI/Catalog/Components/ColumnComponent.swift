import UIKit
import Combine

/// A layout widget that arranges children vertically.
///
/// Parameters:
/// - `children`: Array of child component IDs, or template `{"componentId": "...", "path": "..."}`.
/// - `justify`: Main axis alignment — "start", "center", "end", "spaceBetween", "spaceAround", "spaceEvenly".
/// - `align`: Cross axis alignment — "start", "center", "end", "stretch".
enum ColumnComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Column") { context in
            LayoutComponent.buildStackView(
                context: context,
                axis: .vertical,
                defaultSpacing: 8
            )
        }
    }
}

/// A layout widget that arranges children horizontally.
///
/// Parameters: Same as Column but horizontal. Default spacing is 16px.
enum RowComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Row") { context in
            LayoutComponent.buildStackView(
                context: context,
                axis: .horizontal,
                defaultSpacing: 16
            )
        }
    }
}

/// Shared implementation for Column and Row components.
enum LayoutComponent {

    static func buildStackView(
        context: CatalogItemContext,
        axis: NSLayoutConstraint.Axis,
        defaultSpacing: CGFloat
    ) -> UIView {
        let stackView = UIStackView()
        stackView.axis = axis
        stackView.spacing = defaultSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let justify = context.data["justify"] as? String
        let align = context.data["align"] as? String

        configureDistribution(stackView, justify: justify)
        configureAlignment(stackView, align: align)

        let children = context.data["children"]

        if let childIds = children as? [String] {
            for childId in childIds {
                let childView = buildWeightedChild(
                    childId: childId, context: context, dataContext: nil
                )
                stackView.addArrangedSubview(childView)
            }
        } else if let templateMap = children as? JsonMap,
                  let componentId = templateMap["componentId"] as? String,
                  let pathStr = templateMap["path"] as? String {
            let wrapper = BindableView()
            wrapper.embed(stackView)

            let cancellable = context.dataContext.subscribe(pathString: pathStr)
                .receive(on: DispatchQueue.main)
                .sink { [weak stackView] value in
                    guard let stackView = stackView else { return }
                    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

                    let items: [Any]
                    if let arr = value as? [Any] {
                        items = arr
                    } else if let dict = value as? JsonMap {
                        items = Array(dict.keys)
                    } else {
                        return
                    }

                    for (index, _) in items.enumerated() {
                        let nestedCtx = context.dataContext.nested("\(pathStr)/\(index)")
                        let childView = buildWeightedChild(
                            childId: componentId, context: context, dataContext: nestedCtx
                        )
                        stackView.addArrangedSubview(childView)
                    }
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }

        return stackView
    }

    private static func configureDistribution(_ stackView: UIStackView, justify: String?) {
        switch justify {
        case "center":
            stackView.distribution = .equalCentering
        case "spaceBetween":
            stackView.distribution = .equalSpacing
        case "spaceEvenly":
            stackView.distribution = .equalSpacing
        case "spaceAround":
            stackView.distribution = .equalSpacing
        case "stretch":
            stackView.distribution = .fillEqually
        default:
            stackView.distribution = .fill
        }
    }

    private static func configureAlignment(_ stackView: UIStackView, align: String?) {
        switch align {
        case "center": stackView.alignment = .center
        case "end": stackView.alignment = .trailing
        case "stretch": stackView.alignment = .fill
        default: stackView.alignment = .leading
        }
    }

    /// Builds a child view, wrapping it in a spacer container if a `weight`
    /// property is set, or if the catalog item is implicitly flexible.
    private static func buildWeightedChild(
        childId: String,
        context: CatalogItemContext,
        dataContext: DataContext?
    ) -> UIView {
        let component = context.getComponent(childId)
        let catalogItem = context.getCatalogItem(component?.type ?? "")
        let explicitWeight = component?.properties["weight"] as? Int
        let isImplicitlyFlexible = catalogItem?.isImplicitlyFlexible ?? false

        let childView = context.buildChild(childId, dataContext)

        if let weight = explicitWeight {
            let container = WeightedView(weight: weight, fitTight: true)
            container.embed(childView)
            return container
        } else if isImplicitlyFlexible {
            let container = WeightedView(weight: 1, fitTight: false)
            container.embed(childView)
            return container
        }

        return childView
    }
}

/// A lightweight container that carries flex weight metadata for stack views.
/// UIStackView doesn't natively support flex weights, so we use
/// content hugging/compression priorities to approximate the behavior.
private final class WeightedView: UIView {
    let weight: Int
    let fitTight: Bool

    init(weight: Int, fitTight: Bool) {
        self.weight = weight
        self.fitTight = fitTight
        super.init(frame: .zero)
        backgroundColor = .clear

        let priority = UILayoutPriority(rawValue: max(1, 750 - Float(weight * 10)))
        setContentHuggingPriority(fitTight ? priority : .defaultLow, for: .horizontal)
        setContentHuggingPriority(fitTight ? priority : .defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func embed(_ view: UIView) {
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
