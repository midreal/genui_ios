import UIKit

/// A Macaron layout wrapper that anchors its child to the bottom center.
///
/// In bounded-height layouts this aligns the child to the bottom center.
/// Matches macaron_widgets/bottom_bar.dart behavior.
///
/// Parameters:
/// - `child`: The component ID to anchor to the bottom edge.
enum BottomBarComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "BottomBar") { context in
            guard let childId = context.data["child"] as? String else {
                return UIView()
            }
            let childView = context.buildChild(childId, nil)
            let container = UIView()
            container.backgroundColor = .clear
            container.addSubview(childView)
            childView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                childView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                childView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                childView.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
                childView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
                childView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            ])
            return container
        }
    }
}
