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
            let tabs = context.data["tabs"] as? [JsonMap] ?? []

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 8
            wrapper.embed(stack)

            // Build segmented control with static labels initially;
            // dynamic labels will be updated via subscriptions below.
            let initialLabels = tabs.map { tab -> String in
                (tab["label"] as? String) ?? (tab["title"] as? String) ?? ""
            }
            let segmented = UISegmentedControl(items: initialLabels)
            segmented.selectedSegmentIndex = 0
            stack.addArrangedSubview(segmented)

            // Subscribe to dynamic label bindings
            for (i, tab) in tabs.enumerated() {
                let labelDef = tab["label"] ?? tab["title"]
                if labelDef is JsonMap {
                    let cancellable = BoundValueHelpers.resolveString(labelDef, context: context.dataContext)
                        .receive(on: DispatchQueue.main)
                        .sink { [weak segmented] text in
                            segmented?.setTitle(text ?? "", forSegmentAt: i)
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
                        guard idx >= 0, idx < tabs.count, idx != segmented.selectedSegmentIndex else { return }
                        isUpdatingFromModel = true
                        segmented.selectedSegmentIndex = idx
                        showTab(at: idx)
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                let dataCtx = context.dataContext
                segmented.addAction(UIAction { [weak segmented] _ in
                    guard !isUpdatingFromModel, let idx = segmented?.selectedSegmentIndex else { return }
                    showTab(at: idx)
                    dataCtx.update(pathString: path, value: idx)
                }, for: .valueChanged)
            } else {
                segmented.addAction(UIAction { [weak segmented] _ in
                    guard let idx = segmented?.selectedSegmentIndex else { return }
                    showTab(at: idx)
                }, for: .valueChanged)
            }

            return wrapper
        }
    }
}
