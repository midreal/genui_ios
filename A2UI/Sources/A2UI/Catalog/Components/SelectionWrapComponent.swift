import UIKit
import Combine

/// A horizontal wrapping chip-style selector.
///
/// Parameters: Same as SelectionList. Selection shown via chip border color.
/// Items flow horizontally and wrap to next line.
enum SelectionWrapComponent {

    private static let chipHPad: CGFloat = 16
    private static let chipVPad: CGFloat = 6
    private static let chipRadius: CGFloat = 8
    private static let wrapSpacing: CGFloat = 8
    private static let selectedBorder = MacaronColors.selectionActive
    private static let unselectedBorder = UIColor.clear

    static func register() -> CatalogItem {
        CatalogItem(name: "SelectionWrap") { context in
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

            let flowLayout = WrapFlowLayout()
            flowLayout.minimumInteritemSpacing = wrapSpacing
            flowLayout.minimumLineSpacing = wrapSpacing
            flowLayout.estimatedItemSize = CGSize(width: 80, height: 34)

            let collectionView = DynamicHeightCollectionView(
                frame: .zero,
                collectionViewLayout: flowLayout
            )
            collectionView.backgroundColor = .clear
            collectionView.register(WrapChipCell.self, forCellWithReuseIdentifier: "chip")
            collectionView.isScrollEnabled = false
            wrapper.embed(collectionView)

            let dataSource = WrapDataSource(
                items: items, context: context, constraints: constraints
            )
            collectionView.dataSource = dataSource
            collectionView.delegate = dataSource

            let dataCtx = context.dataContext

            func updateHasSelection(_ selected: [String]) {
                if let path = hasSelPath {
                    dataCtx.update(pathString: path, value: selected.count >= constraints.effectiveRequiredSelection)
                }
            }

            dataSource.onSelectionChanged = { selected in
                guard let path = selectionPath else { return }
                dataCtx.update(pathString: path, value: selected)
                updateHasSelection(selected)
            }

            let selPub = context.dataContext.resolve(selectionDef)
            let cancellable = selPub
                .receive(on: DispatchQueue.main)
                .sink { [weak collectionView] rawValue in
                    let rawArray = (rawValue as? [Any?]) ?? []
                    let selected = normalizeSelectionValues(
                        rawSelection: rawArray, items: items,
                        effectiveMaxSelection: constraints.effectiveMaxSelection
                    )
                    if let path = selectionPath, !isSelectionNormalized(rawArray, selected) {
                        dataCtx.update(pathString: path, value: selected)
                    }
                    updateHasSelection(selected)
                    dataSource.currentSelection = selected
                    collectionView?.reloadData()
                    collectionView?.invalidateIntrinsicContentSize()
                }
            wrapper.storeCancellable(cancellable)

            // Keep data source alive
            objc_setAssociatedObject(wrapper, "wrapDS", dataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            return wrapper
        }
    }
}

// MARK: - Data Source

private final class WrapDataSource: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let items: [JsonMap]
    let context: CatalogItemContext
    let constraints: SelectionConstraints
    var currentSelection: [String] = []
    var onSelectionChanged: (([String]) -> Void)?

    init(items: [JsonMap], context: CatalogItemContext, constraints: SelectionConstraints) {
        self.items = items
        self.context = context
        self.constraints = constraints
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "chip", for: indexPath) as! WrapChipCell
        let item = items[indexPath.item]
        let value = item["value"] as? String ?? ""
        let childId = item["child"] as? String ?? ""
        let isSelected = currentSelection.contains(value)
        let isFull = currentSelection.count >= constraints.effectiveMaxSelection
        let isDisabled = !isSelected && isFull && constraints.effectiveMaxSelection > 1

        cell.configure(
            childView: context.buildChild(childId, nil),
            isSelected: isSelected,
            isDisabled: isDisabled
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let value = items[indexPath.item]["value"] as? String ?? ""
        let isSelected = currentSelection.contains(value)
        let isFull = currentSelection.count >= constraints.effectiveMaxSelection
        let isDisabled = !isSelected && isFull && constraints.effectiveMaxSelection > 1
        guard !isDisabled else { return }

        if isSelected {
            currentSelection.removeAll { $0 == value }
        } else if constraints.effectiveMaxSelection == 1 {
            currentSelection = [value]
        } else if currentSelection.count < constraints.effectiveMaxSelection {
            currentSelection.append(value)
        }
        onSelectionChanged?(currentSelection)
    }
}

// MARK: - Chip Cell

private final class WrapChipCell: UICollectionViewCell {
    private var childContainer: UIView?

    func configure(childView: UIView, isSelected: Bool, isDisabled: Bool) {
        childContainer?.removeFromSuperview()

        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 1
        container.layer.borderColor = isSelected
            ? MacaronColors.selectionActive.cgColor
            : UIColor.clear.cgColor

        childView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(childView)
        NSLayoutConstraint.activate([
            childView.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            childView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            childView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            childView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])

        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])

        // Inject selection scope
        container.macaronScope.selectionSelected = isSelected
        contentView.alpha = isDisabled ? 0.4 : 1.0
        childContainer = container
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        childContainer?.removeFromSuperview()
        childContainer = nil
    }
}

// MARK: - Dynamic Height Collection View

private final class DynamicHeightCollectionView: UICollectionView {
    override var intrinsicContentSize: CGSize {
        collectionViewLayout.collectionViewContentSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != intrinsicContentSize {
            invalidateIntrinsicContentSize()
        }
    }
}

// MARK: - Wrap Flow Layout

private final class WrapFlowLayout: UICollectionViewFlowLayout {
    override init() {
        super.init()
        scrollDirection = .vertical
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}
