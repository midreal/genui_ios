import UIKit

/// A macaron-styled dashed divider line.
///
/// Parameters:
/// - `axis`: "horizontal" (default) or "vertical".
enum DividerComponent {

    private static let dashColor = MacaronColors.tertiary
    private static let strokeWidth: CGFloat = 0.5
    private static let dashLength: CGFloat = 2
    private static let gapLength: CGFloat = 5

    static func register() -> CatalogItem {
        CatalogItem(name: "Divider") { context in
            let axis = context.data["axis"] as? String ?? "horizontal"
            let isVertical = axis == "vertical"

            let divider = DashedLineView(isVertical: isVertical)
            divider.translatesAutoresizingMaskIntoConstraints = false

            if isVertical {
                divider.widthAnchor.constraint(equalToConstant: strokeWidth).isActive = true
            } else {
                divider.heightAnchor.constraint(equalToConstant: strokeWidth).isActive = true
            }
            return divider
        }
    }
}

private final class DashedLineView: UIView {
    let isVertical: Bool

    init(isVertical: Bool) {
        self.isVertical = isVertical
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let color = MacaronColors.tertiary
        let strokeWidth: CGFloat = 0.5
        let dashLength: CGFloat = 2
        let gapLength: CGFloat = 5

        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineDash(phase: 0, lengths: [dashLength, gapLength])

        if isVertical {
            ctx.move(to: CGPoint(x: rect.midX, y: 0))
            ctx.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        } else {
            ctx.move(to: CGPoint(x: 0, y: rect.midY))
            ctx.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        }
        ctx.strokePath()
    }
}
