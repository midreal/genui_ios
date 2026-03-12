import UIKit
import Combine

/// A horizontal progress bar with fixed 8px height.
///
/// Parameters:
/// - `progress`: Number reference in the range [0, 1]. Runtime clamps out-of-range values.
enum LinearProgressComponent {

    private static let barHeight: CGFloat = 8
    private static let trackColor = MacaronColors.trackBackground
    private static let fillColor = UIColor(red: 0xFF/255, green: 0x87/255, blue: 0x00/255, alpha: 1)

    static func register() -> CatalogItem {
        CatalogItem(name: "LinearProgress") { context in
            let wrapper = BindableView()

            let trackView = UIView()
            trackView.backgroundColor = trackColor
            trackView.layer.cornerRadius = barHeight / 2
            trackView.clipsToBounds = true
            trackView.translatesAutoresizingMaskIntoConstraints = false

            let fillView = UIView()
            fillView.backgroundColor = fillColor
            fillView.layer.cornerRadius = barHeight / 2
            fillView.clipsToBounds = true
            fillView.translatesAutoresizingMaskIntoConstraints = false

            trackView.addSubview(fillView)
            wrapper.embed(trackView)

            trackView.heightAnchor.constraint(equalToConstant: barHeight).isActive = true

            NSLayoutConstraint.activate([
                fillView.topAnchor.constraint(equalTo: trackView.topAnchor),
                fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
                fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            ])

            var activeWidthConstraint: NSLayoutConstraint?

            let progressDef = context.data["progress"]
            let cancellable = BoundValueHelpers.resolveNumber(progressDef, context: context.dataContext)
                .receive(on: DispatchQueue.main)
                .sink { [weak trackView, weak fillView] rawValue in
                    guard let trackView = trackView, let fillView = fillView else { return }
                    let progress = CGFloat(min(max(rawValue ?? 0, 0), 1))

                    activeWidthConstraint?.isActive = false
                    let constraint = fillView.widthAnchor.constraint(
                        equalTo: trackView.widthAnchor,
                        multiplier: max(progress, 0.001)
                    )
                    constraint.isActive = true
                    activeWidthConstraint = constraint

                    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
                        trackView.layoutIfNeeded()
                    }
                }
            wrapper.storeCancellable(cancellable)

            return wrapper
        }
    }
}
