import UIKit
import Combine

/// A vertical list-style selector with check indicators.
///
/// Parameters:
/// - `selection`: String array reference bound to data model.
/// - `maxSelection`: Max selectable items (default 1).
/// - `requiredSelection`: Minimum selections for hasSelection (default 1).
/// - `hasSelection`: Optional boolean reference, auto-set when selection is satisfied.
/// - `items`: List of `{value, child}` objects.
enum SelectionListComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "SelectionList") { context in
            let wrapper = BindableView()
            let items = (context.data["items"] as? [JsonMap]) ?? []
            let maxSel = context.data["maxSelection"] as? Int ?? 1
            let reqSel = context.data["requiredSelection"] as? Int ?? 1
            let selectionDef = context.data["selection"] as? JsonMap ?? [:]
            let selectionPath = selectionDef["path"] as? String
            let hasSelDef = context.data["hasSelection"] as? JsonMap
            let hasSelPath = hasSelDef?["path"] as? String

            let constraints = resolveSelectionConstraints(
                itemCount: items.count, maxSelection: maxSel, requiredSelection: reqSel
            )

            if let hasSelPath = hasSelPath, let literal = hasSelDef?["literalBoolean"] as? Bool {
                context.dataContext.update(pathString: hasSelPath, value: literal)
            }

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 16
            stack.alignment = .fill
            wrapper.embed(stack)

            var itemViews: [(container: UIView, checkView: CheckIndicatorView, childView: UIView, value: String)] = []
            for item in items {
                let value = item["value"] as? String ?? ""
                let childId = item["child"] as? String ?? ""

                let row = UIView()
                row.translatesAutoresizingMaskIntoConstraints = false

                let check = CheckIndicatorView()
                check.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(check)
                NSLayoutConstraint.activate([
                    check.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                    check.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                    check.widthAnchor.constraint(equalToConstant: 24),
                    check.heightAnchor.constraint(equalToConstant: 24),
                ])

                let child = context.buildChild(childId, nil)
                child.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(child)
                NSLayoutConstraint.activate([
                    child.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 12),
                    child.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                    child.topAnchor.constraint(equalTo: row.topAnchor),
                    child.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                ])

                stack.addArrangedSubview(row)
                itemViews.append((row, check, child, value))
            }

            let dataCtx = context.dataContext

            func updateHasSelection(_ selected: [String]) {
                if let path = hasSelPath {
                    dataCtx.update(pathString: path, value: selected.count >= constraints.effectiveRequiredSelection)
                }
            }

            let selPub = context.dataContext.resolve(selectionDef)
            let cancellable = selPub
                .receive(on: DispatchQueue.main)
                .sink { rawValue in
                    let rawArray = (rawValue as? [Any?]) ?? []
                    var selected = normalizeSelectionValues(
                        rawSelection: rawArray, items: items,
                        effectiveMaxSelection: constraints.effectiveMaxSelection
                    )
                    if let path = selectionPath, !isSelectionNormalized(rawArray, selected) {
                        dataCtx.update(pathString: path, value: selected)
                    }
                    updateHasSelection(selected)

                    let isFull = selected.count >= constraints.effectiveMaxSelection

                    for entry in itemViews {
                        let isSelected = selected.contains(entry.value)
                        let isDisabled = !isSelected && isFull && constraints.effectiveMaxSelection > 1
                        entry.checkView.isChecked = isSelected
                        entry.checkView.setNeedsDisplay()
                        entry.container.alpha = isDisabled ? 0.4 : 1.0
                        entry.container.isUserInteractionEnabled = !isDisabled

                        entry.container.gestureRecognizers?.forEach { entry.container.removeGestureRecognizer($0) }
                        if !isDisabled {
                            let tap = SelectionTapGesture(target: nil, action: nil)
                            tap.itemValue = entry.value
                            tap.addTarget(wrapper, action: #selector(BindableView.handleSelectionTap(_:)))
                            entry.container.addGestureRecognizer(tap)
                        }
                    }

                    wrapper.selectionTapHandler = { tappedValue in
                        guard let path = selectionPath else { return }
                        let isSelected = selected.contains(tappedValue)
                        if isSelected {
                            selected.removeAll { $0 == tappedValue }
                        } else if constraints.effectiveMaxSelection == 1 {
                            selected = [tappedValue]
                        } else if selected.count < constraints.effectiveMaxSelection {
                            selected.append(tappedValue)
                        }
                        dataCtx.update(pathString: path, value: selected)
                        updateHasSelection(selected)
                    }
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }
    }
}

// MARK: - Check Indicator Drawing

final class CheckIndicatorView: UIView {
    var isChecked = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

        if isChecked {
            ctx.setFillColor(MacaronColors.selectionActive.cgColor)
            ctx.addArc(center: center, radius: radius - 1, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()

            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(1.25)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: 7.5, y: 12))
            ctx.addLine(to: CGPoint(x: 11, y: 16.5))
            ctx.addLine(to: CGPoint(x: 16.5, y: 8))
            ctx.strokePath()
        } else {
            ctx.setStrokeColor(MacaronColors.tertiary.cgColor)
            ctx.setLineWidth(1.5)
            ctx.addArc(center: center, radius: radius - 1.75, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()
        }
    }
}

// MARK: - Selection Tap Gesture

final class SelectionTapGesture: UITapGestureRecognizer {
    var itemValue: String = ""
}

extension BindableView {
    typealias SelectionTapHandler = (String) -> Void

    private static var handlerKey: UInt8 = 0

    var selectionTapHandler: SelectionTapHandler? {
        get { objc_getAssociatedObject(self, &Self.handlerKey) as? SelectionTapHandler }
        set { objc_setAssociatedObject(self, &Self.handlerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @objc func handleSelectionTap(_ gesture: SelectionTapGesture) {
        selectionTapHandler?(gesture.itemValue)
    }
}
