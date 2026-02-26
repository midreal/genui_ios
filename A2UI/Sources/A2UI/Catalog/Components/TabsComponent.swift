import UIKit
import Combine

/// A tabbed container that switches between child components.
///
/// Parameters:
/// - `tabs`: Array of `{"label": "...", "child": "<componentId>"}` objects.
/// - `activeTab`: Data binding path for the active tab index (number, bidirectional).
enum TabsComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Tabs") { context in
            let wrapper = BindableView()
            let tabs = context.data["tabs"] as? [JsonMap] ?? []
            let activeTabBinding = context.data["activeTab"] as? String

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 8
            wrapper.embed(stack)

            let labels = tabs.map { $0["label"] as? String ?? "" }
            let segmented = UISegmentedControl(items: labels)
            segmented.selectedSegmentIndex = 0
            stack.addArrangedSubview(segmented)

            let contentContainer = UIView()
            contentContainer.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(contentContainer)

            func showTab(at index: Int) {
                contentContainer.subviews.forEach { $0.removeFromSuperview() }
                guard index >= 0, index < tabs.count else { return }
                let tab = tabs[index]
                if let childId = tab["child"] as? String {
                    let childView = context.buildChild(childId, nil)
                    contentContainer.addSubview(childView)
                    childView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        childView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                        childView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                        childView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                        childView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
                    ])
                }
            }

            showTab(at: 0)

            if let path = activeTabBinding {
                var isUpdatingFromModel = false

                let cancellable = context.dataContext.subscribe(pathString: path)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak segmented] value in
                        guard let segmented = segmented else { return }
                        let idx: Int
                        if let n = value as? Int { idx = n }
                        else if let n = value as? NSNumber { idx = n.intValue }
                        else { return }
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
