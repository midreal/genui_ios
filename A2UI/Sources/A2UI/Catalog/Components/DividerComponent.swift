import UIKit

/// A horizontal divider line.
enum DividerComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Divider") { context in
            let divider = UIView()
            divider.backgroundColor = .separator
            divider.translatesAutoresizingMaskIntoConstraints = false
            divider.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
            return divider
        }
    }
}
