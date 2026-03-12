import UIKit
import Combine

/// A horizontal pager container where each page uses 80% of parent width
/// with 8px spacing.
///
/// Parameters:
/// - `children.explicitList`: Ordered list of component IDs rendered as pages.
enum CarouselComponent {

    static let itemWidthFraction: CGFloat = 0.8
    private static let itemSpacing: CGFloat = 8

    static func register() -> CatalogItem {
        CatalogItem(name: "Carousel") { context in
            let childrenMap = context.data["children"] as? JsonMap ?? [:]
            let childIds = childrenMap["explicitList"] as? [String] ?? []

            guard !childIds.isEmpty else {
                return UIView()
            }

            let wrapper = BindableView()

            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = itemSpacing

            let collectionView = CarouselCollectionView(
                frame: .zero,
                collectionViewLayout: layout
            )
            collectionView.backgroundColor = .clear
            collectionView.showsHorizontalScrollIndicator = false
            collectionView.decelerationRate = .fast
            collectionView.clipsToBounds = false
            collectionView.isPagingEnabled = false

            if childIds.count == 1 {
                collectionView.isScrollEnabled = false
            }

            let dataSource = CarouselDataSource(
                childIds: childIds,
                context: context
            )
            collectionView.register(CarouselCell.self, forCellWithReuseIdentifier: "CarouselCell")
            collectionView.dataSource = dataSource
            collectionView.delegate = dataSource

            wrapper.embed(collectionView)

            objc_setAssociatedObject(wrapper, &carouselDataSourceKey, dataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            return wrapper
        }
    }
}

private var carouselDataSourceKey: UInt8 = 0

private final class CarouselCollectionView: UICollectionView {
    private var hasSetInitialSize = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasSetInitialSize, bounds.width > 0 else { return }
        hasSetInitialSize = true
        if let layout = collectionViewLayout as? UICollectionViewFlowLayout {
            let itemWidth = bounds.width * CarouselComponent.itemWidthFraction
            layout.itemSize = CGSize(width: itemWidth, height: bounds.height)
            layout.invalidateLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 200)
    }
}

private final class CarouselCell: UICollectionViewCell {
    func configure(with view: UIView) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentView.topAnchor),
            view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}

private final class CarouselDataSource: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let childIds: [String]
    let context: CatalogItemContext
    private var builtViews: [String: UIView] = [:]

    init(childIds: [String], context: CatalogItemContext) {
        self.childIds = childIds
        self.context = context
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        childIds.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CarouselCell", for: indexPath) as! CarouselCell
        let childId = childIds[indexPath.item]
        let childView: UIView
        if let existing = builtViews[childId] {
            childView = existing
        } else {
            childView = context.buildChild(childId, nil)
            builtViews[childId] = childView
        }
        cell.configure(with: childView)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width * CarouselComponent.itemWidthFraction
        return CGSize(width: width, height: collectionView.bounds.height)
    }
}
