import UIKit

/// A modal/bottom-sheet component. The Modal component itself is a placeholder;
/// showing is triggered via ActionDelegate interception of `showModal` events.
///
/// Parameters:
/// - `child`: The component ID to render inside the modal.
/// - `title`: Optional title for the modal sheet.
enum ModalComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Modal") { context in
            let childId = context.data["child"] as? String
            let title = context.data["title"] as? String

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 8

            if let t = title {
                let label = UILabel()
                label.text = t
                label.font = .systemFont(ofSize: 18, weight: .semibold)
                stack.addArrangedSubview(label)
            }

            if let cid = childId {
                let childView = context.buildChild(cid, nil)
                stack.addArrangedSubview(childView)
            }

            return stack
        }
    }
}
