import UIKit
import Combine

/// A scrollable list that supports both explicit children and data-bound template rendering.
///
/// Parameters:
/// - `children`: Array of child IDs, or template `{"componentId": "...", "path": "..."}`.
enum ListComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "List", isImplicitlyFlexible: true) { context in
            let children = context.data["children"]

            if let childIds = children as? [String] {
                return buildExplicitList(context: context, childIds: childIds)
            }
            if let template = children as? JsonMap,
               let componentId = template["componentId"] as? String,
               let pathStr = template["path"] as? String {
                return buildTemplateList(context: context, componentId: componentId, path: pathStr)
            }

            let label = UILabel()
            label.text = "List: no children defined"
            label.textColor = .secondaryLabel
            return label
        }
    }

    private static func buildExplicitList(context: CatalogItemContext, childIds: [String]) -> UIView {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        scrollView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        for childId in childIds {
            let childView = context.buildChild(childId, nil)
            stack.addArrangedSubview(childView)
        }

        return scrollView
    }

    private static func buildTemplateList(
        context: CatalogItemContext,
        componentId: String,
        path: String
    ) -> UIView {
        let wrapper = BindableView()
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        wrapper.embed(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        scrollView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let cancellable = context.dataContext.subscribe(pathString: path)
            .receive(on: DispatchQueue.main)
            .sink { [weak stack] value in
                guard let stack = stack else { return }
                stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

                let items: [Any]
                if let arr = value as? [Any] {
                    items = arr
                } else if let dict = value as? JsonMap {
                    items = Array(dict.keys)
                } else {
                    return
                }

                for (index, _) in items.enumerated() {
                    let nestedCtx = context.dataContext.nested("\(path)/\(index)")
                    let childView = context.buildChild(componentId, nestedCtx)
                    stack.addArrangedSubview(childView)
                }
            }
        wrapper.storeCancellable(cancellable)

        return wrapper
    }
}
