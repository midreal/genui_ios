import UIKit
import Combine

/// An ordered list-style selector showing pick order as 1..n badges.
///
/// Parameters: Same as SelectionList. Selected items show a red order badge
/// instead of a check indicator.
enum OrderedSelectionListComponent {

    private static let selectedBadgeColor = UIColor(red: 0xFF/255, green: 0x59/255, blue: 0x6C/255, alpha: 1)
    private static let unselectedStrokeColor = MacaronColors.tertiary

    static func register() -> CatalogItem {
        CatalogItem(name: "OrderedSelectionList") { context in
            let wrapper = BindableView()
            let items = (context.data["items"] as? [JsonMap]) ?? []
            let maxSel = context.data["maxSelection"] as? Int ?? 1
            let reqSel = context.data["requiredSelection"] as? Int ?? 1
            let selectionDef = context.data["selection"] as? JsonMap ?? [:]
            let selectionPath = selectionDef["path"] as? String
            let hasSelDef = context.data["hasSelection"] as? JsonMap
            let hasSelPath = hasSelDef?["path"] as? String

            if let hasSelPath = hasSelPath, let literal = hasSelDef?["literalBoolean"] as? Bool {
                context.dataContext.update(pathString: hasSelPath, value: literal)
            }

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 16
            stack.alignment = .fill
            wrapper.embed(stack)

            var itemViews: [(container: UIView, badge: OrderSelectionBadgeView, value: String)] = []
            for item in items {
                let value = item["value"] as? String ?? ""
                let childId = item["child"] as? String ?? ""

                let row = UIView()
                row.translatesAutoresizingMaskIntoConstraints = false

                let badge = OrderSelectionBadgeView()
                badge.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(badge)
                NSLayoutConstraint.activate([
                    badge.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                    badge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                    badge.widthAnchor.constraint(equalToConstant: 24),
                    badge.heightAnchor.constraint(equalToConstant: 24),
                ])

                let child = context.buildChild(childId, nil)
                child.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(child)
                NSLayoutConstraint.activate([
                    child.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
                    child.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                    child.topAnchor.constraint(equalTo: row.topAnchor),
                    child.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                ])

                stack.addArrangedSubview(row)
                itemViews.append((row, badge, value))
            }

            let dataCtx = context.dataContext

            func updateHasSelection(_ selected: [Any?]) {
                if let path = hasSelPath {
                    dataCtx.update(pathString: path, value: selected.count >= reqSel)
                }
            }

            let selPub = context.dataContext.resolve(selectionDef)
            let cancellable = selPub
                .receive(on: DispatchQueue.main)
                .sink { rawValue in
                    var selected = ((rawValue as? [Any?]) ?? [])
                    let isFull = selected.count >= maxSel

                    for entry in itemViews {
                        let idx = selected.firstIndex(where: { ($0 as? String) == entry.value })
                        let isSelected = idx != nil
                        let isDisabled = !isSelected && isFull && maxSel > 1

                        if let idx = idx {
                            entry.badge.orderNumber = idx + 1
                        } else {
                            entry.badge.orderNumber = nil
                        }
                        entry.badge.setNeedsDisplay()
                        entry.container.alpha = isDisabled ? 0.4 : 1.0

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
                        let idx = selected.firstIndex(where: { ($0 as? String) == tappedValue })
                        if idx != nil {
                            selected.removeAll { ($0 as? String) == tappedValue }
                        } else if maxSel == 1 {
                            selected = [tappedValue]
                        } else if selected.count < maxSel {
                            selected.append(tappedValue)
                        }
                        dataCtx.update(pathString: path, value: selected.compactMap { $0 as? String })
                        updateHasSelection(selected)
                    }
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }
    }
}

// MARK: - Order Selection Badge (selectable items, shows number when selected)

private final class OrderSelectionBadgeView: UIView {
    var orderNumber: Int?

    private let numberLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        addSubview(numberLabel)
        NSLayoutConstraint.activate([
            numberLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

        if let order = orderNumber {
            let badgeColor = UIColor(red: 0xFF/255, green: 0x59/255, blue: 0x6C/255, alpha: 1)
            ctx.setFillColor(badgeColor.cgColor)
            ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()
            numberLabel.text = "\(order)"
            numberLabel.isHidden = false
        } else {
            ctx.setStrokeColor(MacaronColors.tertiary.cgColor)
            ctx.setLineWidth(1.5)
            ctx.addArc(center: center, radius: radius - 1.75, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()
            numberLabel.isHidden = true
        }
    }
}
