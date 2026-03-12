import UIKit
import Combine

/// A pure display wrap-style tag group for Macaron filter labels.
///
/// Parameters:
/// - `tags`: A path/literal reference to an array of tag strings.
enum FilterTagsComponent {

    private static let wrapSpacing: CGFloat = 8
    private static let tagHorizontalPadding: CGFloat = 8
    private static let tagRadius: CGFloat = 8
    private static let tagBackgroundColor = UIColor(red: 0x16/255, green: 0x16/255, blue: 0x15/255, alpha: 0.05)
    private static let tagFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    private static let tagTextColor = MacaronColors.label

    static func register() -> CatalogItem {
        CatalogItem(name: "FilterTags") { context in
            let wrapper = BindableView()

            let container = FilterTagsFlowView()
            container.translatesAutoresizingMaskIntoConstraints = false
            wrapper.embed(container)

            let tagsDef = context.data["tags"]
            let cancellable = context.dataContext.resolve(tagsDef)
                .receive(on: DispatchQueue.main)
                .sink { [weak container] value in
                    guard let container = container else { return }
                    let tags: [String]
                    if let arr = value as? [Any] {
                        tags = arr.compactMap { item -> String? in
                            guard let s = item as? String, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                            return s
                        }
                    } else {
                        tags = []
                    }
                    container.setTags(tags)
                }
            wrapper.storeCancellable(cancellable)

            return wrapper
        }
    }
}

private final class FilterTagsFlowView: UIView {
    private var tagViews: [UIView] = []

    func setTags(_ tags: [String]) {
        tagViews.forEach { $0.removeFromSuperview() }
        tagViews.removeAll()

        for tag in tags {
            let label = UILabel()
            label.text = tag
            label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            label.textColor = MacaronColors.label

            let container = UIView()
            container.backgroundColor = UIColor(red: 0x16/255, green: 0x16/255, blue: 0x15/255, alpha: 0.05)
            container.layer.cornerRadius = 8
            container.clipsToBounds = true

            container.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            ])

            addSubview(container)
            tagViews.append(container)
        }
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let spacing: CGFloat = 8
        let maxWidth = bounds.width > 0 ? bounds.width : .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in tagViews {
            let size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    override var intrinsicContentSize: CGSize {
        let spacing: CGFloat = 8
        let maxWidth = bounds.width > 0 ? bounds.width : 300
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in tagViews {
            let size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: UIView.noIntrinsicMetric, height: y + rowHeight)
    }
}
