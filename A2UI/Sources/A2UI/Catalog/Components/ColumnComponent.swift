import UIKit
import Combine

/// A layout widget that arranges children vertically.
///
/// Parameters:
/// - `children`: Array of child component IDs, or template `{"componentId": "...", "path": "..."}`.
/// - `justify`: Main axis alignment — "start", "center", "end", "spaceBetween".
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
/// Parameters: Same as Column but horizontal.
enum RowComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Row") { context in
            LayoutComponent.buildStackView(
                context: context,
                axis: .horizontal,
                defaultSpacing: 8
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

        switch justify {
        case "center": stackView.distribution = .equalCentering
        case "spaceBetween": stackView.distribution = .equalSpacing
        case "spaceEvenly": stackView.distribution = .equalSpacing
        default: stackView.distribution = .fill
        }

        switch align {
        case "center": stackView.alignment = .center
        case "end": stackView.alignment = .trailing
        case "stretch": stackView.alignment = .fill
        default: stackView.alignment = .leading
        }

        let children = context.data["children"]

        if let childIds = children as? [String] {
            for childId in childIds {
                let childView = context.buildChild(childId, nil)
                stackView.addArrangedSubview(childView)
            }
        } else if let templateMap = children as? JsonMap,
                  let componentId = templateMap["componentId"] as? String,
                  let pathStr = templateMap["path"] as? String {
            let wrapper = BindableView()
            wrapper.embed(stackView)

            let cancellable = context.dataContext.subscribe(pathString: pathStr)
                .receive(on: DispatchQueue.main)
                .sink { [weak stackView, weak wrapper] value in
                    guard let stackView = stackView, let _ = wrapper else { return }
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
                        let childView = context.buildChild(componentId, nestedCtx)
                        stackView.addArrangedSubview(childView)
                    }
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }

        return stackView
    }
}
