import UIKit
import Combine

/// A tabbed container that switches between child components.
///
/// Parameters:
/// - `tabs`: Array of `{"label": "...", "child": "<componentId>"}` objects.
enum TabsComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Tabs") { context in
            let wrapper = BindableView()
            let tabs = context.data["tabs"] as? [JsonMap] ?? []

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

            segmented.addAction(UIAction { [weak segmented] _ in
                guard let idx = segmented?.selectedSegmentIndex else { return }
                showTab(at: idx)
            }, for: .valueChanged)

            return wrapper
        }
    }
}
