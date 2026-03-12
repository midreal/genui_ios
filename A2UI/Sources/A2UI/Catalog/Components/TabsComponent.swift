import UIKit
import Combine

/// A tabbed container that switches between child components using
/// show/hide (preserving all tab content state like IndexedStack).
///
/// Parameters:
/// - `tabs`: Array of `{"label": "...", "content": "<componentId>"}` objects.
///   Also accepts `child` as a fallback for `content`, and `title` for `label`.
/// - `activeTab`: Active tab index. Supports `{path: "..."}`, number literal,
///   or plain string path. Bidirectional binding.
enum TabsComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Tabs") { context in
            let wrapper = BindableView()
            // Support both "tabs" (legacy) and "tabItems" (macaron) keys
            var tabs = context.data["tabs"] as? [JsonMap] ?? context.data["tabItems"] as? [JsonMap] ?? []
            // Macaron: limit to 3 tabs
            if tabs.count > 3 { tabs = Array(tabs.prefix(3)) }

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 12
            wrapper.embed(stack)

            // Build capsule track segmented control
            let segmented = MacaronSegmentedControl(itemCount: tabs.count)
            segmented.translatesAutoresizingMaskIntoConstraints = false
            segmented.heightAnchor.constraint(equalToConstant: 42).isActive = true
            stack.addArrangedSubview(segmented)

            // Subscribe to dynamic label bindings
            for (i, tab) in tabs.enumerated() {
                let labelDef = tab["label"] ?? tab["title"]
                if let staticTitle = labelDef as? String {
                    segmented.setTitle(staticTitle, at: i)
                } else if labelDef is JsonMap {
                    let cancellable = BoundValueHelpers.resolveString(labelDef, context: context.dataContext)
                        .receive(on: DispatchQueue.main)
                        .sink { [weak segmented] text in
                            segmented?.setTitle(text ?? "", at: i)
                        }
                    wrapper.storeCancellable(cancellable)
                }
            }

            // Build ALL tab content views upfront and toggle visibility
            let contentContainer = UIView()
            contentContainer.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(contentContainer)

            var contentViews: [UIView] = []
            for tab in tabs {
                let childId = (tab["content"] as? String) ?? (tab["child"] as? String)
                let childView: UIView
                if let cid = childId {
                    childView = context.buildChild(cid, nil)
                } else {
                    let placeholder = UILabel()
                    placeholder.text = "Tab: missing content"
                    placeholder.textColor = .secondaryLabel
                    childView = placeholder
                }
                childView.translatesAutoresizingMaskIntoConstraints = false
                contentContainer.addSubview(childView)
                NSLayoutConstraint.activate([
                    childView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                    childView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                    childView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                    childView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
                ])
                childView.isHidden = true
                contentViews.append(childView)
            }
            contentViews.first?.isHidden = false

            func showTab(at index: Int) {
                for (i, view) in contentViews.enumerated() {
                    view.isHidden = (i != index)
                }
            }

            // Resolve activeTab binding (supports {path: "..."}, number, or plain string)
            let activeTabDef = BoundValueHelpers.readValueDef(from: context.data.merging(
                ["value": context.data["activeTab"] as Any].compactMapValues { $0 }
            ) { _, new in new }.merging(["binding": "\(context.id).activeTab"]) { old, _ in old })
            let writablePath = BoundValueHelpers.extractWritablePath(
                context.data["activeTab"] ?? ["path": "\(context.id).activeTab"] as JsonMap
            )

            if let path = writablePath {
                var isUpdatingFromModel = false

                let resolvedDef: Any? = context.data["activeTab"] ?? ["path": path] as JsonMap
                let cancellable = BoundValueHelpers.resolveNumber(resolvedDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak segmented] value in
                        guard let segmented = segmented else { return }
                        let idx = Int(value ?? 0)
                        guard idx >= 0, idx < tabs.count, idx != segmented.selectedIndex else { return }
                        isUpdatingFromModel = true
                        segmented.selectedIndex = idx
                        showTab(at: idx)
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                let dataCtx = context.dataContext
                segmented.onIndexChanged = { idx in
                    guard !isUpdatingFromModel else { return }
                    showTab(at: idx)
                    dataCtx.update(pathString: path, value: idx)
                }
            } else {
                segmented.onIndexChanged = { idx in
                    showTab(at: idx)
                }
            }

            return wrapper
        }
    }
}

// MARK: - Macaron Capsule Segmented Control

private final class MacaronSegmentedControl: UIView {
    private let trackColor = MacaronColors.trackBackground
    private let thumbColor = UIColor.white
    private let labelColor = MacaronColors.label
    private var labels: [UILabel] = []
    private let thumbView = UIView()
    var selectedIndex: Int = 0 {
        didSet { updateThumbPosition(animated: true); onIndexChanged?(selectedIndex) }
    }
    var onIndexChanged: ((Int) -> Void)?

    init(itemCount: Int) {
        super.init(frame: .zero)
        backgroundColor = trackColor
        layer.cornerRadius = 999
        clipsToBounds = true

        thumbView.backgroundColor = thumbColor
        thumbView.layer.cornerRadius = 999
        addSubview(thumbView)

        for i in 0..<itemCount {
            let label = UILabel()
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 13.33, weight: .medium)
            label.textColor = labelColor
            label.tag = i
            addSubview(label)
            labels.append(label)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleLabelTap(_:)))
            label.addGestureRecognizer(tap)
            label.isUserInteractionEnabled = true
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func setTitle(_ title: String, at index: Int) {
        guard index < labels.count else { return }
        labels[index].text = title
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let count = labels.count
        guard count > 0 else { return }
        let padding: CGFloat = 3
        let innerWidth = bounds.width - padding * 2
        let segWidth = innerWidth / CGFloat(count)
        let segHeight = bounds.height - padding * 2

        for (i, label) in labels.enumerated() {
            label.frame = CGRect(
                x: padding + CGFloat(i) * segWidth,
                y: padding,
                width: segWidth,
                height: segHeight
            )
        }

        thumbView.frame = CGRect(
            x: padding + CGFloat(selectedIndex) * segWidth,
            y: padding,
            width: segWidth,
            height: segHeight
        )
        thumbView.layer.cornerRadius = segHeight / 2
    }

    private func updateThumbPosition(animated: Bool) {
        let count = labels.count
        guard count > 0 else { return }
        let padding: CGFloat = 3
        let innerWidth = bounds.width - padding * 2
        let segWidth = innerWidth / CGFloat(count)
        let segHeight = bounds.height - padding * 2

        let targetFrame = CGRect(
            x: padding + CGFloat(selectedIndex) * segWidth,
            y: padding,
            width: segWidth,
            height: segHeight
        )

        if animated {
            UIView.animate(withDuration: 0.24, delay: 0, options: .curveEaseOut) {
                self.thumbView.frame = targetFrame
            }
        } else {
            thumbView.frame = targetFrame
        }
    }

    @objc private func handleLabelTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel else { return }
        let index = label.tag
        guard index != selectedIndex else { return }
        selectedIndex = index
    }
}
