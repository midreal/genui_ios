import UIKit

/// A card container with rounded corners and shadow.
///
/// Parameters:
/// - `child`: The ID of the single child component to display inside the card.
enum CardComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Card") { context in
            let card = UIView()
            card.backgroundColor = .secondarySystemBackground
            card.layer.cornerRadius = 12
            card.layer.shadowColor = UIColor.black.cgColor
            card.layer.shadowOffset = CGSize(width: 0, height: 2)
            card.layer.shadowRadius = 4
            card.layer.shadowOpacity = 0.1
            card.clipsToBounds = false

            let contentView = UIView()
            contentView.clipsToBounds = true
            contentView.layer.cornerRadius = 12
            card.addSubview(contentView)
            contentView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                contentView.topAnchor.constraint(equalTo: card.topAnchor),
                contentView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: card.bottomAnchor)
            ])

            let padding: CGFloat = 16
            if let childId = context.data["child"] as? String {
                let childView = context.buildChild(childId, nil)
                contentView.addSubview(childView)
                childView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    childView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
                    childView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
                    childView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
                    childView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding)
                ])
            } else if let childIds = context.data["children"] as? [String] {
                let stack = UIStackView()
                stack.axis = .vertical
                stack.spacing = 8
                contentView.addSubview(stack)
                stack.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
                    stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
                    stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
                    stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding)
                ])
                for childId in childIds {
                    stack.addArrangedSubview(context.buildChild(childId, nil))
                }
            }

            return card
        }
    }
}
