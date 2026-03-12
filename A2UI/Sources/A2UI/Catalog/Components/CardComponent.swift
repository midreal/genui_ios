import UIKit

/// A card container with rounded corners and shadow.
///
/// Parameters:
/// - `child`: The ID of the single child component to display inside the card.
enum CardComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Card") { context in
            let card = UIView()
            card.backgroundColor = MacaronColors.cardBackground
            card.layer.cornerRadius = 16
            card.layer.borderWidth = 1
            card.layer.borderColor = MacaronColors.cardBorder.cgColor
            card.clipsToBounds = true

            // Inject card scope so child Column gets 12px spacing
            card.macaronScope.cardActive = true

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

            let padding: CGFloat = 12
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

            let margin: CGFloat = 4
            let wrapper = UIView()
            wrapper.backgroundColor = .clear
            wrapper.addSubview(card)
            card.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: margin),
                card.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: margin),
                card.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -margin),
                card.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -margin)
            ])

            return wrapper
        }
    }
}
