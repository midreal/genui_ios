import UIKit
import Combine

/// A pure display tag group for Macaron filter labels.
/// 使用 UIStackView 实现，避免 UICollectionView 的布局循环和 watchdog 超时。
///
/// Parameters:
/// - `tags`: A path/literal reference to an array of tag strings.
enum FilterTagsComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "FilterTags") { context in
            let wrapper = BindableView()
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 8
            stack.alignment = .center
            stack.distribution = .fill
            stack.translatesAutoresizingMaskIntoConstraints = false

            wrapper.embed(stack)

            let tagsDef = context.data["tags"]
            let cancellable = context.dataContext.resolve(tagsDef)
                .receive(on: DispatchQueue.main)
                .sink { [weak stack] value in
                    guard let stack = stack else { return }
                    let tags: [String]
                    if let arr = value as? [Any] {
                        tags = arr.compactMap { item -> String? in
                            guard let s = item as? String, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                            return s
                        }
                    } else {
                        tags = []
                    }
                    // 延后到下一 run loop，避免在布局/约束更新中同步修改导致 watchdog 超时
                    DispatchQueue.main.async { [weak stack] in
                        guard let stack = stack else { return }
                        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                        for tag in tags {
                            let chip = makeTagChip(tag: tag)
                            stack.addArrangedSubview(chip)
                        }
                    }
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }
    }

    private static func makeTagChip(tag: String) -> UIView {
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
        return container
    }
}
