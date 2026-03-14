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
            // 同步设置 spacing，避免 async 在布局后改 spacing 触发 layout 循环
            let align = context.data["align"] as? String
            let defaultSpacing: CGFloat = (align == "stretch") ? 12 : 0
            let view = LayoutComponent.buildStackView(
                context: context,
                axis: .vertical,
                defaultSpacing: defaultSpacing
            )
            // 非 stretch 时仍用 async 检查 card  scope（如 center/start 的 Column 在 Card 内）
            if align != "stretch" {
                DispatchQueue.main.async { [weak view] in
                    guard let view = view else { return }
                    if view.macaronCardActive() {
                        if let stack = view as? UIStackView { stack.spacing = 12 }
                        else if let stack = view.subviews.first as? UIStackView { stack.spacing = 12 }
                        view.macaronScope.cardActive = false
                    }
                }
            }
            return view
        }
    }
}

/// A layout widget that arranges children horizontally.
///
/// Parameters: Same as Column but horizontal. Default spacing is 16px.
enum RowComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Row") { context in
            let view = LayoutComponent.buildStackView(
                context: context,
                axis: .horizontal,
                defaultSpacing: 12
            )
            // If inside a button scope, use 4px spacing
            DispatchQueue.main.async { [weak view] in
                guard let view = view else { return }
                if view.macaronButtonStyle() != nil {
                    if let stack = view as? UIStackView {
                        stack.spacing = 4
                    } else if let stack = view.subviews.first as? UIStackView {
                        stack.spacing = 4
                    }
                }
            }
            return view
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
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let justify = context.data["justify"] as? String ?? "start"
        let align = context.data["align"] as? String

        let useSpacers = ["spaceBetween", "spaceAround", "spaceEvenly", "end", "center"].contains(justify)
        stackView.spacing = useSpacers ? 0 : defaultSpacing
        if !useSpacers {
            configureDistribution(stackView, justify: justify)
        } else {
            stackView.distribution = .fill
        }
        configureAlignment(stackView, align: align)

        let children = context.data["children"]

        if let childIds = children as? [String] {
            let childViews = childIds.map { buildWeightedChild(childId: $0, context: context, dataContext: nil) }
            if useSpacers {
                addChildrenWithSpacers(to: stackView, children: childViews, justify: justify, spacing: defaultSpacing)
            } else {
                childViews.forEach { stackView.addArrangedSubview($0) }
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

                    var childViews: [UIView] = []
                    if let arr = value as? [Any] {
                        for (index, _) in arr.enumerated() {
                            let nestedCtx = context.dataContext.nested("\(pathStr)/\(index)")
                            let childView = buildWeightedChild(
                                childId: componentId, context: context, dataContext: nestedCtx
                            )
                            childViews.append(childView)
                        }
                    } else if let dict = value as? JsonMap {
                        for key in dict.keys.sorted() {
                            let nestedCtx = context.dataContext.nested("\(pathStr)/\(key)")
                            let childView = buildWeightedChild(
                                childId: componentId, context: context, dataContext: nestedCtx
                            )
                            childViews.append(childView)
                        }
                    } else {
                        return
                    }

                    if useSpacers {
                        addChildrenWithSpacers(to: stackView, children: childViews, justify: justify, spacing: defaultSpacing)
                    } else {
                        childViews.forEach { stackView.addArrangedSubview($0) }
                    }
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }

        return stackView
    }

    /// Inserts child views with flexible spacer views to achieve the
    /// requested justify behavior that UIStackView cannot natively express.
    private static func addChildrenWithSpacers(
        to stackView: UIStackView,
        children: [UIView],
        justify: String,
        spacing: CGFloat
    ) {
        guard !children.isEmpty else { return }

        switch justify {
        case "end":
            stackView.addArrangedSubview(makeFlexSpacer())
            for (i, child) in children.enumerated() {
                stackView.addArrangedSubview(child)
                if i < children.count - 1 {
                    stackView.addArrangedSubview(makeFixedSpacer(spacing, axis: stackView.axis))
                }
            }

        case "center":
            stackView.addArrangedSubview(makeFlexSpacer())
            for (i, child) in children.enumerated() {
                stackView.addArrangedSubview(child)
                if i < children.count - 1 {
                    stackView.addArrangedSubview(makeFixedSpacer(spacing, axis: stackView.axis))
                }
            }
            stackView.addArrangedSubview(makeFlexSpacer())

        case "spaceBetween":
            for (i, child) in children.enumerated() {
                stackView.addArrangedSubview(child)
                if i < children.count - 1 {
                    stackView.addArrangedSubview(makeFlexSpacer())
                }
            }

        case "spaceAround":
            let halfSpacer = { () -> UIView in
                let s = makeFlexSpacer()
                s.setContentHuggingPriority(.defaultLow, for: stackView.axis)
                return s
            }
            stackView.addArrangedSubview(halfSpacer())
            for (i, child) in children.enumerated() {
                stackView.addArrangedSubview(child)
                if i < children.count - 1 {
                    stackView.addArrangedSubview(makeFlexSpacer())
                }
            }
            stackView.addArrangedSubview(halfSpacer())

        case "spaceEvenly":
            stackView.addArrangedSubview(makeFlexSpacer())
            for (i, child) in children.enumerated() {
                stackView.addArrangedSubview(child)
                if i < children.count - 1 {
                    stackView.addArrangedSubview(makeFlexSpacer())
                }
            }
            stackView.addArrangedSubview(makeFlexSpacer())

        default:
            children.forEach { stackView.addArrangedSubview($0) }
        }
    }

    private static func makeFlexSpacer() -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        v.setContentHuggingPriority(.init(1), for: .horizontal)
        v.setContentHuggingPriority(.init(1), for: .vertical)
        v.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        v.setContentCompressionResistancePriority(.init(1), for: .vertical)
        return v
    }

    private static func makeFixedSpacer(_ size: CGFloat, axis: NSLayoutConstraint.Axis) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        if axis == .horizontal {
            v.widthAnchor.constraint(equalToConstant: size).isActive = true
        } else {
            v.heightAnchor.constraint(equalToConstant: size).isActive = true
        }
        return v
    }

    private static func configureDistribution(_ stackView: UIStackView, justify: String?) {
        switch justify {
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
