import UIKit
import Combine

/// A button-like single-select dropdown.
///
/// Parameters:
/// - `selection`: String array reference (single-select).
/// - `items`: Plain string array of options.
/// - `placeholder`: Optional placeholder text reference.
/// - `hasSelection`: Optional boolean reference.
enum DropdownSelectionComponent {

    private static let triggerHPad: CGFloat = 16
    private static let triggerVPad: CGFloat = 6
    private static let triggerRadius: CGFloat = 8
    private static let menuRadius: CGFloat = 12
    private static let menuPadding: CGFloat = 12
    private static let menuTopGap: CGFloat = 8
    private static let menuMaxHeight: CGFloat = 280
    private static let placeholderColor = MacaronColors.tertiary
    private static let textColor = MacaronColors.label
    private static let checkColor = MacaronColors.selectionActive
    private static let defaultPlaceholder = "Select location"

    static func register() -> CatalogItem {
        CatalogItem(name: "DropdownSelection", isImplicitlyFlexible: true) { context in
            let wrapper = BindableView()
            let selectionDef = context.data["selection"] as? JsonMap ?? [:]
            let selectionPath = selectionDef["path"] as? String
            let items = (context.data["items"] as? [String]) ?? []
            let hasSelDef = context.data["hasSelection"] as? JsonMap
            let hasSelPath = hasSelDef?["path"] as? String

            if let hasSelPath = hasSelPath, let literal = hasSelDef?["literalBoolean"] as? Bool {
                context.dataContext.update(pathString: hasSelPath, value: literal)
            }

            let triggerButton = UIButton(type: .system)
            triggerButton.contentHorizontalAlignment = .center
            triggerButton.backgroundColor = .white
            triggerButton.layer.cornerRadius = triggerRadius
            triggerButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
            triggerButton.contentEdgeInsets = UIEdgeInsets(
                top: triggerVPad, left: triggerHPad, bottom: triggerVPad, right: triggerHPad
            )
            wrapper.embed(triggerButton)

            let dataCtx = context.dataContext

            func resolveSelectedValue(_ rawSelection: [Any?]) -> String? {
                let validSet = Set(items)
                for raw in rawSelection {
                    if let s = raw as? String, validSet.contains(s) { return s }
                }
                return nil
            }

            func updateHasSelection(_ rawSelection: [Any?]) {
                guard let path = hasSelPath else { return }
                dataCtx.update(pathString: path, value: resolveSelectedValue(rawSelection) != nil)
            }

            // Resolve placeholder
            let placeholderDef = context.data["placeholder"]
            let placeholderPub = BoundValueHelpers.resolveString(placeholderDef, context: dataCtx)

            let selPub = dataCtx.resolve(selectionDef)
            let cancellable = selPub.combineLatest(placeholderPub)
                .receive(on: DispatchQueue.main)
                .sink { [weak triggerButton] rawValue, placeholderVal in
                    guard let button = triggerButton else { return }
                    let rawArray = (rawValue as? [Any?]) ?? []
                    let selectedValue = resolveSelectedValue(rawArray)
                    updateHasSelection(rawArray)

                    let placeholder = (placeholderVal?.isEmpty ?? true) ? defaultPlaceholder : placeholderVal!
                    let displayText = selectedValue ?? placeholder
                    let color = selectedValue == nil ? placeholderColor : textColor

                    button.setTitle(displayText, for: .normal)
                    button.setTitleColor(color, for: .normal)
                }
            wrapper.storeCancellable(cancellable)

            // Tap to show dropdown
            triggerButton.addAction(UIAction { [weak wrapper, weak triggerButton] _ in
                guard let wrapper = wrapper, let button = triggerButton else { return }
                showDropdown(
                    from: button, in: wrapper, items: items,
                    selectionPath: selectionPath, hasSelPath: hasSelPath,
                    dataContext: dataCtx
                )
            }, for: .touchUpInside)

            return wrapper
        }
    }

    private static func showDropdown(
        from button: UIButton,
        in wrapper: UIView,
        items: [String],
        selectionPath: String?,
        hasSelPath: String?,
        dataContext: DataContext
    ) {
        guard let window = button.window else { return }
        let buttonFrame = button.convert(button.bounds, to: window)

        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = .clear
        window.addSubview(overlay)

        let dismissTap = UITapGestureRecognizer(target: overlay, action: nil)
        let dismiss: () -> Void = { [weak overlay] in overlay?.removeFromSuperview() }
        dismissTap.addTarget(overlay as Any, action: #selector(UIView.removeFromSuperview))

        let bgView = UIView(frame: overlay.bounds)
        bgView.backgroundColor = .clear
        bgView.addGestureRecognizer(UITapGestureRecognizer(target: nil, action: nil))
        bgView.addGestureRecognizer(dismissTap)
        overlay.addSubview(bgView)

        let menuTop = buttonFrame.maxY + menuTopGap
        let menuWidth = buttonFrame.width
        let menuFrame = CGRect(x: buttonFrame.minX, y: menuTop, width: menuWidth, height: 0)

        let menu = UIView(frame: menuFrame)
        menu.backgroundColor = .white
        menu.layer.cornerRadius = menuRadius
        menu.layer.shadowColor = UIColor.black.cgColor
        menu.layer.shadowOffset = CGSize(width: 0, height: 4)
        menu.layer.shadowRadius = 10
        menu.layer.shadowOpacity = 0.1
        menu.clipsToBounds = false
        overlay.addSubview(menu)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        menu.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: menu.topAnchor, constant: menuPadding),
            stackView.leadingAnchor.constraint(equalTo: menu.leadingAnchor, constant: menuPadding),
            stackView.trailingAnchor.constraint(equalTo: menu.trailingAnchor, constant: -menuPadding),
            stackView.bottomAnchor.constraint(equalTo: menu.bottomAnchor, constant: -menuPadding),
        ])

        let currentRaw = (dataContext.getValue(pathString: selectionPath ?? "") as? [Any?]) ?? []
        let validSet = Set(items)
        let currentSelected = currentRaw.compactMap { $0 as? String }.first(where: { validSet.contains($0) })

        for item in items {
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true

            let label = UILabel()
            label.text = item
            label.font = .systemFont(ofSize: 14, weight: .regular)
            label.textColor = textColor
            label.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])

            if item == currentSelected {
                let check = UIImageView()
                check.image = UIImage(systemName: "checkmark")
                check.tintColor = checkColor
                check.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(check)
                NSLayoutConstraint.activate([
                    check.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                    check.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                    check.widthAnchor.constraint(equalToConstant: 13),
                    check.heightAnchor.constraint(equalToConstant: 12),
                ])
            }

            let itemTap = UITapGestureRecognizer()
            row.addGestureRecognizer(itemTap)
            row.isUserInteractionEnabled = true
            let capturedItem = item
            itemTap.addAction { [weak overlay] in
                if let path = selectionPath {
                    dataContext.update(pathString: path, value: [capturedItem])
                }
                if let hasPath = hasSelPath {
                    dataContext.update(pathString: hasPath, value: true)
                }
                overlay?.removeFromSuperview()
            }

            stackView.addArrangedSubview(row)
        }

        // Size the menu
        menu.layoutIfNeeded()
        let contentSize = stackView.systemLayoutSizeFitting(
            CGSize(width: menuWidth - menuPadding * 2, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let menuHeight = min(contentSize.height + menuPadding * 2, menuMaxHeight)
        menu.frame = CGRect(x: buttonFrame.minX, y: menuTop, width: menuWidth, height: menuHeight)
    }
}

// MARK: - UITapGestureRecognizer action helper

private extension UITapGestureRecognizer {
    private static var actionKey: UInt8 = 0

    func addAction(_ action: @escaping () -> Void) {
        let handler = TapHandler(action: action)
        objc_setAssociatedObject(self, &Self.actionKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        addTarget(handler, action: #selector(TapHandler.handleTap))
    }
}

private final class TapHandler: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func handleTap() { action() }
}
