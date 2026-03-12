import UIKit
import Combine

/// An adaptive up-to-3-column grid selector.
///
/// Parameters: Same as SelectionList. Check indicator overlaid at top-right.
enum SelectionGridComponent {

    private static let maxGridColumns = 3
    private static let gridGap: CGFloat = 12

    static func register() -> CatalogItem {
        CatalogItem(name: "SelectionGrid") { context in
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

            let flowContainer = FlowLayoutView()
            flowContainer.spacing = gridGap
            flowContainer.columnCount = min(items.count, maxGridColumns)
            wrapper.embed(flowContainer)

            var cellEntries: [(cell: UIView, check: CheckIndicatorView, value: String)] = []
            for item in items {
                let value = item["value"] as? String ?? ""
                let childId = item["child"] as? String ?? ""

                let cell = UIView()
                cell.translatesAutoresizingMaskIntoConstraints = false

                let child = context.buildChild(childId, nil)
                child.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(child)
                NSLayoutConstraint.activate([
                    child.topAnchor.constraint(equalTo: cell.topAnchor),
                    child.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                    child.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                    child.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
                ])

                let check = CheckIndicatorView()
                check.translatesAutoresizingMaskIntoConstraints = false
                check.isUserInteractionEnabled = false
                cell.addSubview(check)
                NSLayoutConstraint.activate([
                    check.topAnchor.constraint(equalTo: cell.topAnchor, constant: 2),
                    check.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                    check.widthAnchor.constraint(equalToConstant: 24),
                    check.heightAnchor.constraint(equalToConstant: 24),
                ])

                flowContainer.addArrangedSubview(cell)
                cellEntries.append((cell, check, value))
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

                    for entry in cellEntries {
                        let isSelected = selected.contains(entry.value)
                        let isDisabled = !isSelected && isFull && constraints.effectiveMaxSelection > 1
                        entry.check.isChecked = isSelected
                        entry.check.setNeedsDisplay()
                        entry.cell.alpha = isDisabled ? 0.4 : 1.0
                        entry.cell.isUserInteractionEnabled = !isDisabled

                        entry.cell.gestureRecognizers?.forEach { entry.cell.removeGestureRecognizer($0) }
                        if !isDisabled {
                            let tap = SelectionTapGesture(target: nil, action: nil)
                            tap.itemValue = entry.value
                            tap.addTarget(wrapper, action: #selector(BindableView.handleSelectionTap(_:)))
                            entry.cell.addGestureRecognizer(tap)
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

// MARK: - Flow Layout View (simple grid)

/// A simple auto-layout-based grid that distributes subviews into equal-width columns.
final class FlowLayoutView: UIView {
    var spacing: CGFloat = 12
    var columnCount: Int = 3

    private var arrangedSubviews: [UIView] = []
    private var gridConstraints: [NSLayoutConstraint] = []

    func addArrangedSubview(_ view: UIView) {
        arrangedSubviews.append(view)
        addSubview(view)
        setNeedsUpdateConstraints()
    }

    override func updateConstraints() {
        NSLayoutConstraint.deactivate(gridConstraints)
        gridConstraints.removeAll()

        guard !arrangedSubviews.isEmpty, columnCount > 0 else {
            super.updateConstraints()
            return
        }

        let cols = columnCount
        var previousRowBottom: NSLayoutYAxisAnchor = topAnchor
        var rowTopConstant: CGFloat = 0

        for rowStart in stride(from: 0, to: arrangedSubviews.count, by: cols) {
            let rowEnd = min(rowStart + cols, arrangedSubviews.count)
            let rowViews = Array(arrangedSubviews[rowStart..<rowEnd])

            for (colIndex, view) in rowViews.enumerated() {
                view.translatesAutoresizingMaskIntoConstraints = false

                gridConstraints.append(view.topAnchor.constraint(equalTo: previousRowBottom, constant: rowTopConstant))

                if colIndex == 0 {
                    gridConstraints.append(view.leadingAnchor.constraint(equalTo: leadingAnchor))
                } else {
                    gridConstraints.append(view.leadingAnchor.constraint(
                        equalTo: rowViews[colIndex - 1].trailingAnchor, constant: spacing
                    ))
                }

                gridConstraints.append(view.widthAnchor.constraint(equalTo: rowViews[0].widthAnchor))

                if colIndex == cols - 1 || colIndex == rowViews.count - 1 {
                    if rowViews.count == cols {
                        gridConstraints.append(view.trailingAnchor.constraint(equalTo: trailingAnchor))
                    }
                }
            }

            if let firstInRow = rowViews.first {
                previousRowBottom = firstInRow.bottomAnchor
                rowTopConstant = spacing
            }
        }

        if let lastView = arrangedSubviews.last {
            gridConstraints.append(lastView.bottomAnchor.constraint(equalTo: bottomAnchor))
        }

        NSLayoutConstraint.activate(gridConstraints)
        super.updateConstraints()
    }
}
