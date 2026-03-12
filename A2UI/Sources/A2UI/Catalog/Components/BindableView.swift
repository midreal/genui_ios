import UIKit
import Combine

/// A lightweight UIView wrapper that holds Combine cancellables.
///
/// Used by components that need to manage reactive subscriptions
/// tied to the view's lifecycle.
public final class BindableView: UIView {

    private var cancellables = Set<AnyCancellable>()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Stores a cancellable to be released when this view is deallocated.
    public func storeCancellable(_ cancellable: AnyCancellable) {
        cancellables.insert(cancellable)
    }

    /// Embeds a subview with edge-pinned constraints.
    public func embed(_ view: UIView, insets: UIEdgeInsets = .zero) {
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom)
        ])
    }

    deinit {
        cancellables.removeAll()
    }
}
