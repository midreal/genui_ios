import UIKit
import Combine

/// A scrollable list that supports both explicit children and data-bound template rendering.
///
/// Parameters:
/// - `children`: Array of child IDs, or template `{"componentId": "...", "path": "..."}`.
/// - `direction`: `"vertical"` (default) or `"horizontal"`.
/// - `align`: Cross axis alignment — `"start"`, `"center"` (default), `"end"`, `"stretch"`.
/// A UIScrollView subclass whose intrinsic content size tracks its content size,
/// so Auto Layout can give it a natural height inside UIStackView containers.
private final class AutoSizingScrollView: UIScrollView {
    override var contentSize: CGSize {
        didSet {
            if contentSize != oldValue {
                invalidateIntrinsicContentSize()
            }
        }
    }

    override var intrinsicContentSize: CGSize {
        contentSize
    }
}

enum ListComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "List", isImplicitlyFlexible: true) { context in
            let children = context.data["children"]
            let direction = context.data["direction"] as? String ?? "vertical"
            let align = context.data["align"] as? String ?? "center"
            let isHorizontal = direction == "horizontal"

            if let childIds = children as? [String] {
                return buildExplicitList(context: context, childIds: childIds, isHorizontal: isHorizontal, align: align)
            }
            if let template = children as? JsonMap,
               let componentId = template["componentId"] as? String,
               let pathStr = template["path"] as? String {
                return buildTemplateList(context: context, componentId: componentId, path: pathStr, isHorizontal: isHorizontal, align: align)
            }

            let label = UILabel()
            label.text = "List: no children defined"
            label.textColor = .secondaryLabel
            return label
        }
    }

    private static func configureScrollAndStack(
        scrollView: UIScrollView,
        stack: UIStackView,
        isHorizontal: Bool,
        align: String
    ) {
        let axis: NSLayoutConstraint.Axis = isHorizontal ? .horizontal : .vertical
        stack.axis = axis
        stack.spacing = 0

        if isHorizontal {
            scrollView.alwaysBounceHorizontal = true
            scrollView.alwaysBounceVertical = false
        } else {
            scrollView.alwaysBounceVertical = true
            scrollView.alwaysBounceHorizontal = false
        }

        switch align {
        case "start": stack.alignment = .leading
        case "end": stack.alignment = .trailing
        case "stretch": stack.alignment = .fill
        default: stack.alignment = .fill
        }

        scrollView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentGuide = scrollView.contentLayoutGuide
        let frameGuide = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
        ])

        if isHorizontal {
            stack.heightAnchor.constraint(equalTo: frameGuide.heightAnchor).isActive = true
        } else {
            stack.widthAnchor.constraint(equalTo: frameGuide.widthAnchor).isActive = true
        }
    }

    private static func buildExplicitList(
        context: CatalogItemContext,
        childIds: [String],
        isHorizontal: Bool,
        align: String
    ) -> UIView {
        let scrollView = AutoSizingScrollView()
        let stack = UIStackView()
        configureScrollAndStack(scrollView: scrollView, stack: stack, isHorizontal: isHorizontal, align: align)

        for childId in childIds {
            let childView = context.buildChild(childId, nil)
            stack.addArrangedSubview(childView)
        }

        return scrollView
    }

    private static func buildTemplateList(
        context: CatalogItemContext,
        componentId: String,
        path: String,
        isHorizontal: Bool,
        align: String
    ) -> UIView {
        let wrapper = BindableView()
        let scrollView = AutoSizingScrollView()
        wrapper.embed(scrollView)

        let stack = UIStackView()
        configureScrollAndStack(scrollView: scrollView, stack: stack, isHorizontal: isHorizontal, align: align)

        let cancellable = context.dataContext.subscribe(pathString: path)
            .receive(on: DispatchQueue.main)
            .sink { [weak stack] value in
                guard let stack = stack else { return }
                stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

                if let arr = value as? [Any] {
                    for (index, _) in arr.enumerated() {
                        let nestedCtx = context.dataContext.nested("\(path)/\(index)")
                        let childView = context.buildChild(componentId, nestedCtx)
                        stack.addArrangedSubview(childView)
                    }
                } else if let dict = value as? JsonMap {
                    for key in dict.keys.sorted() {
                        let nestedCtx = context.dataContext.nested("\(path)/\(key)")
                        let childView = context.buildChild(componentId, nestedCtx)
                        stack.addArrangedSubview(childView)
                    }
                }
            }
        wrapper.storeCancellable(cancellable)

        return wrapper
    }
}
