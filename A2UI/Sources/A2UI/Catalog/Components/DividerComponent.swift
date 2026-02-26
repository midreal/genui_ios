import UIKit

/// A divider line, horizontal or vertical.
///
/// Parameters:
/// - `axis`: "horizontal" (default) or "vertical".
enum DividerComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Divider") { context in
            let axis = context.data["axis"] as? String ?? "horizontal"
            let divider = UIView()
            divider.backgroundColor = .separator
            divider.translatesAutoresizingMaskIntoConstraints = false

            let thickness = 1.0 / UIScreen.main.scale
            if axis == "vertical" {
                divider.widthAnchor.constraint(equalToConstant: thickness).isActive = true
            } else {
                divider.heightAnchor.constraint(equalToConstant: thickness).isActive = true
            }
            return divider
        }
    }
}
