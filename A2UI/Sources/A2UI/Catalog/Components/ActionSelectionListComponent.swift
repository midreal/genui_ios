import UIKit
import Combine

/// A single-select list that dispatches an action on first selection.
/// Once selected, the list is locked.
///
/// Parameters:
/// - `selection`: String array reference.
/// - `action`: Action definition with `name` and optional `context`.
/// - `items`: List of `{value, child}` objects.
enum ActionSelectionListComponent {

    private static let itemGap: CGFloat = 12
    private static let hPad: CGFloat = 20
    private static let vPad: CGFloat = 12
    private static let selectedRadius: CGFloat = 48
    private static let unselectedRadius: CGFloat = 1000
    private static let selectedBorder = MacaronColors.selectionActive
    private static let unselectedBorder = MacaronColors.cardBorder

    static func register() -> CatalogItem {
        CatalogItem(name: "ActionSelectionList") { context in
            let wrapper = BindableView()
            let items = (context.data["items"] as? [JsonMap]) ?? []
            let selectionDef = context.data["selection"] as? JsonMap ?? [:]
            let selectionPath = selectionDef["path"] as? String
            let actionDef = context.data["action"] as? JsonMap ?? [:]
            let actionName = actionDef["name"] as? String ?? ""
            let contextDefinition = actionDef["context"] as? [Any?] ?? []

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = itemGap
            stack.alignment = .fill
            wrapper.embed(stack)

            var itemContainers: [(container: UIView, value: String, index: Int)] = []
            for (i, item) in items.enumerated() {
                let value = item["value"] as? String ?? ""
                let childId = item["child"] as? String ?? ""

                let container = UIView()
                container.backgroundColor = .white
                container.layer.borderWidth = 1
                container.layer.borderColor = unselectedBorder.cgColor
                container.layer.cornerRadius = unselectedRadius
                container.clipsToBounds = true

                let child = context.buildChild(childId, nil)
                child.translatesAutoresizingMaskIntoConstraints = false
                child.isUserInteractionEnabled = false
                container.addSubview(child)
                NSLayoutConstraint.activate([
                    child.topAnchor.constraint(equalTo: container.topAnchor, constant: vPad),
                    child.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPad),
                    child.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad),
                    child.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -hPad),
                ])

                // Inject selection scope (will be updated reactively)
                container.macaronScope.selectionSelected = false

                stack.addArrangedSubview(container)
                itemContainers.append((container, value, i))
            }

            let dataCtx = context.dataContext
            let dispatch = context.dispatchEvent
            let componentId = context.id

            let selPub = context.dataContext.resolve(selectionDef)
            let cancellable = selPub
                .receive(on: DispatchQueue.main)
                .sink { rawValue in
                    let rawArray = (rawValue as? [Any?]) ?? []
                    let selectedValue = resolveSelectedValue(rawArray, items)
                    let isLocked = selectedValue != nil

                    for entry in itemContainers {
                        let isSelected = entry.value == selectedValue
                        let isDisabled = isLocked && !isSelected
                        let isInteractive = !isLocked && selectionPath != nil

                        entry.container.layer.borderColor = isSelected
                            ? selectedBorder.cgColor
                            : unselectedBorder.cgColor
                        entry.container.layer.cornerRadius = isSelected ? selectedRadius : unselectedRadius
                        entry.container.alpha = isDisabled ? 0.4 : 1.0
                        entry.container.macaronScope.selectionSelected = isSelected

                        entry.container.gestureRecognizers?.forEach { entry.container.removeGestureRecognizer($0) }
                        if isInteractive {
                            let tap = SelectionTapGesture(target: nil, action: nil)
                            tap.itemValue = entry.value
                            tap.addTarget(wrapper, action: #selector(BindableView.handleSelectionTap(_:)))
                            entry.container.addGestureRecognizer(tap)
                        }
                    }

                    wrapper.selectionTapHandler = { tappedValue in
                        guard let path = selectionPath else { return }
                        dataCtx.update(pathString: path, value: [tappedValue])

                        // Resolve context and dispatch action
                        let tappedIndex = items.firstIndex(where: { ($0["value"] as? String) == tappedValue }) ?? 0
                        var resolvedCtx: JsonMap = [:]
                        // Resolve context entries from contextDefinition array
                        if let contextArray = contextDefinition as? [JsonMap] {
                            for entry in contextArray {
                                if let key = entry["key"] as? String {
                                    if let valueDef = entry["value"] as? JsonMap,
                                       let literalString = valueDef["literalString"] as? String {
                                        resolvedCtx[key] = literalString
                                    } else if let valueDef = entry["value"] {
                                        resolvedCtx[key] = valueDef
                                    }
                                }
                            }
                        }
                        resolvedCtx["selectedValue"] = tappedValue
                        resolvedCtx["selectedIndex"] = tappedIndex

                        let event = UiEvent(data: [
                            "name": actionName,
                            "sourceComponentId": componentId,
                            "timestamp": ISO8601DateFormatter().string(from: Date()),
                            "context": resolvedCtx,
                        ])
                        dispatch(event)
                    }
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }
    }

    private static func resolveSelectedValue(_ rawSelection: [Any?], _ items: [JsonMap]) -> String? {
        let validValues = Set(items.compactMap { $0["value"] as? String })
        for raw in rawSelection {
            if let value = raw as? String, validValues.contains(value) {
                return value
            }
        }
        return nil
    }
}
