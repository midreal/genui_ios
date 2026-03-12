import UIKit
import Combine

/// A read-only 5-star rating display with optional text.
///
/// Parameters:
/// - `rating`: Number reference (0-5). Rounded and clamped.
/// - `text`: Optional string reference displayed beside the stars.
enum RatingComponent {

    private static let starCount = 5
    private static let starWidth: CGFloat = 13
    private static let starHeight: CGFloat = 12
    private static let starSpacing: CGFloat = 2
    private static let selectedColor = UIColor(red: 0xFF/255, green: 0x87/255, blue: 0x00/255, alpha: 1)
    private static let unselectedColor = UIColor(red: 0xDA/255, green: 0xD8/255, blue: 0xD3/255, alpha: 1)

    static func register() -> CatalogItem {
        CatalogItem(name: "Rating") { context in
            let wrapper = BindableView()
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = 0
            wrapper.embed(stack)

            let starsStack = UIStackView()
            starsStack.axis = .horizontal
            starsStack.spacing = starSpacing
            stack.addArrangedSubview(starsStack)

            var starViews: [StarView] = []
            for _ in 0..<starCount {
                let star = StarView()
                star.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    star.widthAnchor.constraint(equalToConstant: starWidth),
                    star.heightAnchor.constraint(equalToConstant: starHeight),
                ])
                starsStack.addArrangedSubview(star)
                starViews.append(star)
            }

            let textLabel = UILabel()
            textLabel.font = .systemFont(ofSize: 12, weight: .regular)
            textLabel.textColor = MacaronColors.tertiary
            textLabel.isHidden = true
            stack.addArrangedSubview(textLabel)

            let ratingPub = BoundValueHelpers.resolveNumber(context.data["rating"], context: context.dataContext)
            let textPub = BoundValueHelpers.resolveString(context.data["text"], context: context.dataContext)

            let cancellable = ratingPub.combineLatest(textPub)
                .receive(on: DispatchQueue.main)
                .sink { [weak textLabel] rawRating, rawText in
                    guard let textLabel = textLabel else { return }
                    let count = normalizeRating(rawRating)
                    for (i, star) in starViews.enumerated() {
                        star.starColor = i < count ? selectedColor : unselectedColor
                        star.setNeedsDisplay()
                    }
                    if let text = rawText, !text.isEmpty {
                        textLabel.text = text
                        textLabel.isHidden = false
                    } else {
                        textLabel.isHidden = true
                    }
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }
    }

    private static func normalizeRating(_ value: Double?) -> Int {
        guard let v = value else { return 0 }
        return min(max(Int(v.rounded()), 0), starCount)
    }
}

// MARK: - Star Drawing

private final class StarView: UIView {
    var starColor: UIColor = .clear

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let path = Self.starPath(in: rect)
        ctx.addPath(path)
        ctx.setFillColor(starColor.cgColor)
        ctx.fillPath()
    }

    private static func starPath(in rect: CGRect) -> CGPath {
        let scaleX = rect.width / 13.0
        let scaleY = rect.height / 12.0
        let path = CGMutablePath()
        var t = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let base = CGMutablePath()
        base.move(to: CGPoint(x: 5.644, y: 0.355))
        base.addCurve(to: CGPoint(x: 6.753, y: 0.355), control1: CGPoint(x: 5.862, y: -0.118), control2: CGPoint(x: 6.535, y: -0.118))
        base.addLine(to: CGPoint(x: 8.124, y: 3.327))
        base.addCurve(to: CGPoint(x: 8.607, y: 3.678), control1: CGPoint(x: 8.213, y: 3.520), control2: CGPoint(x: 8.396, y: 3.653))
        base.addLine(to: CGPoint(x: 11.857, y: 4.064))
        base.addCurve(to: CGPoint(x: 12.200, y: 5.119), control1: CGPoint(x: 12.375, y: 4.125), control2: CGPoint(x: 12.583, y: 4.765))
        base.addLine(to: CGPoint(x: 9.797, y: 7.341))
        base.addCurve(to: CGPoint(x: 9.613, y: 7.909), control1: CGPoint(x: 9.641, y: 7.485), control2: CGPoint(x: 9.572, y: 7.700))
        base.addLine(to: CGPoint(x: 10.251, y: 11.119))
        base.addCurve(to: CGPoint(x: 9.353, y: 11.771), control1: CGPoint(x: 10.352, y: 11.631), control2: CGPoint(x: 9.808, y: 12.026))
        base.addLine(to: CGPoint(x: 6.497, y: 10.173))
        base.addCurve(to: CGPoint(x: 5.900, y: 10.173), control1: CGPoint(x: 6.312, y: 10.069), control2: CGPoint(x: 6.086, y: 10.069))
        base.addLine(to: CGPoint(x: 3.044, y: 11.771))
        base.addCurve(to: CGPoint(x: 2.146, y: 11.119), control1: CGPoint(x: 2.589, y: 12.026), control2: CGPoint(x: 2.045, y: 11.631))
        base.addLine(to: CGPoint(x: 2.784, y: 7.909))
        base.addCurve(to: CGPoint(x: 2.600, y: 7.341), control1: CGPoint(x: 2.826, y: 7.700), control2: CGPoint(x: 2.756, y: 7.485))
        base.addLine(to: CGPoint(x: 0.197, y: 5.119))
        base.addCurve(to: CGPoint(x: 0.540, y: 4.064), control1: CGPoint(x: -0.186, y: 4.765), control2: CGPoint(x: 0.022, y: 4.125))
        base.addLine(to: CGPoint(x: 3.790, y: 3.678))
        base.addCurve(to: CGPoint(x: 4.273, y: 3.327), control1: CGPoint(x: 4.001, y: 3.653), control2: CGPoint(x: 4.184, y: 3.520))
        base.closeSubpath()
        path.addPath(base, transform: t)
        return path
    }
}
