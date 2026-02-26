import UIKit

/// A modal overlay that presents content in a bottom sheet.
///
/// Parameters:
/// - `trigger`: The component ID that opens the modal (rendered inline).
/// - `content`: The component ID to display inside the modal sheet.
enum ModalComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Modal") { context in
            let triggerChildId = context.data["trigger"] as? String
            let contentChildId = context.data["content"] as? String

            guard let triggerId = triggerChildId else {
                let label = UILabel()
                label.text = "Modal: missing trigger"
                label.textColor = .secondaryLabel
                return label
            }

            let wrapper = BindableView()

            let triggerView = context.buildChild(triggerId, nil)
            wrapper.embed(triggerView)

            let overlayButton = UIButton(type: .system)
            overlayButton.setTitle("", for: .normal)
            wrapper.addSubview(overlayButton)
            overlayButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                overlayButton.topAnchor.constraint(equalTo: wrapper.topAnchor),
                overlayButton.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                overlayButton.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                overlayButton.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
            ])

            let buildChild = context.buildChild

            overlayButton.addAction(UIAction { _ in
                guard let contentId = contentChildId else { return }

                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
                let presenter = topMostViewController(from: rootVC)

                let sheetVC = ModalSheetController()
                let contentView = buildChild(contentId, nil)
                sheetVC.configure(with: contentView)

                if let sheet = sheetVC.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                }

                presenter.present(sheetVC, animated: true)
            }, for: .touchUpInside)

            return wrapper
        }
    }

    private static func topMostViewController(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let nav = vc as? UINavigationController, let top = nav.topViewController {
            return topMostViewController(from: top)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return vc
    }
}

/// A lightweight UIViewController that hosts a single content UIView in a sheet.
private class ModalSheetController: UIViewController {

    private var contentView: UIView?

    func configure(with view: UIView) {
        self.contentView = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        guard let contentView = contentView else { return }
        view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
}
