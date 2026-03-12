import UIKit

/// A pure display ordered list with 1-based circular order badges.
///
/// Parameters:
/// - `items`: Array of `{child: "<componentId>"}` objects rendered in order.
enum OrderedDisplayListComponent {

    private static let badgeStrokeColor = UIColor(red: 0xFF/255, green: 0x59/255, blue: 0x6C/255, alpha: 1)
    private static let badgeDiameter: CGFloat = 22
    private static let itemSpacing: CGFloat = 16
    private static let badgeToContentSpacing: CGFloat = 12

    static func register() -> CatalogItem {
        CatalogItem(name: "OrderedDisplayList") { context in
            let items = context.data["items"] as? [JsonMap] ?? []
            guard !items.isEmpty else { return UIView() }

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = itemSpacing

            for (i, item) in items.enumerated() {
                guard let childId = item["child"] as? String else { continue }

                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = badgeToContentSpacing
                row.alignment = .center

                let badge = OrderBadgeView(order: i + 1, color: badgeStrokeColor, diameter: badgeDiameter)
                badge.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    badge.widthAnchor.constraint(equalToConstant: 24),
                    badge.heightAnchor.constraint(equalToConstant: 24),
                ])
                row.addArrangedSubview(badge)

                let childView = context.buildChild(childId, nil)
                row.addArrangedSubview(childView)

                stack.addArrangedSubview(row)
            }

            return stack
        }
    }
}

/// Reusable circular badge view showing an order number.
final class OrderBadgeView: UIView {
    private let label = UILabel()

    init(order: Int, color: UIColor, diameter: CGFloat) {
        super.init(frame: .zero)

        layer.cornerRadius = diameter / 2
        layer.borderWidth = 1
        layer.borderColor = color.cgColor
        backgroundColor = .clear

        label.text = "\(order)"
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = color
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}
