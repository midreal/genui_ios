import UIKit
import Combine

/// A circular progress indicator with value/max display.
///
/// Parameters:
/// - `value`: Current progress value (number reference).
/// - `max`: Maximum progress value (number reference).
/// - `style`: `"positive"` (#8CA62A) or `"danger"` (#F63B39). Defaults to `"positive"`.
/// - `iconName`: Optional SF Symbol name for center content.
enum CircularProgressComponent {

    private static let diameter: CGFloat = 120
    private static let strokeWidth: CGFloat = 8
    private static let trackColor = MacaronColors.trackBackground

    static func register() -> CatalogItem {
        CatalogItem(name: "CircularProgress") { context in
            let wrapper = BindableView()
            let style = context.data["style"] as? String ?? "positive"
            let progressColor = style == "danger" ? MacaronColors.danger : MacaronColors.selectionActive

            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: diameter),
                container.heightAnchor.constraint(equalToConstant: diameter),
            ])

            let trackLayer = CAShapeLayer()
            trackLayer.fillColor = nil
            trackLayer.strokeColor = trackColor.cgColor
            trackLayer.lineWidth = strokeWidth

            let progressLayer = CAShapeLayer()
            progressLayer.fillColor = nil
            progressLayer.strokeColor = progressColor.cgColor
            progressLayer.lineWidth = strokeWidth
            progressLayer.lineCap = .round
            progressLayer.strokeEnd = 0

            container.layer.addSublayer(trackLayer)
            container.layer.addSublayer(progressLayer)

            let centerLabel = UILabel()
            centerLabel.textAlignment = .center
            centerLabel.font = LabelComponent.resolveFont(variant: "title")
            centerLabel.textColor = MacaronColors.label
            centerLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(centerLabel)
            NSLayoutConstraint.activate([
                centerLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                centerLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])

            let centerIcon = UIImageView()
            centerIcon.tintColor = progressColor
            centerIcon.contentMode = .scaleAspectFit
            centerIcon.translatesAutoresizingMaskIntoConstraints = false
            centerIcon.isHidden = true
            container.addSubview(centerIcon)
            NSLayoutConstraint.activate([
                centerIcon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                centerIcon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                centerIcon.widthAnchor.constraint(equalToConstant: 42),
                centerIcon.heightAnchor.constraint(equalToConstant: 42),
            ])

            // Layout circle paths after layout pass
            container.layoutIfNeeded()
            let updatePaths = { [weak container] in
                guard let container = container else { return }
                let bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
                let inset = strokeWidth / 2
                let rect = bounds.insetBy(dx: inset, dy: inset)
                let path = UIBezierPath(ovalIn: rect)
                trackLayer.path = path.cgPath
                trackLayer.frame = bounds

                let progressPath = UIBezierPath(
                    arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                    radius: (diameter - strokeWidth) / 2,
                    startAngle: -.pi / 2,
                    endAngle: .pi * 3 / 2,
                    clockwise: true
                )
                progressLayer.path = progressPath.cgPath
                progressLayer.frame = bounds
            }

            DispatchQueue.main.async { updatePaths() }

            let valuePub = BoundValueHelpers.resolveNumber(context.data["value"], context: context.dataContext)
            let maxPub = BoundValueHelpers.resolveNumber(context.data["max"], context: context.dataContext)
            let iconPub = BoundValueHelpers.resolveString(context.data["iconName"], context: context.dataContext)

            let cancellable = valuePub.combineLatest(maxPub, iconPub)
                .receive(on: DispatchQueue.main)
                .sink { [weak centerLabel, weak centerIcon] rawValue, rawMax, iconName in
                    guard let centerLabel = centerLabel, let centerIcon = centerIcon else { return }
                    let maxVal = max(rawMax ?? 0, 0)
                    let val = maxVal > 0 ? min(max(rawValue ?? 0, 0), maxVal) : 0
                    let ratio = maxVal > 0 ? CGFloat(val / maxVal) : 0

                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    progressLayer.strokeEnd = ratio
                    CATransaction.commit()

                    if let name = iconName, !name.isEmpty,
                       let image = UIImage(systemName: name) {
                        centerIcon.image = image
                        centerIcon.isHidden = false
                        centerLabel.isHidden = true
                    } else {
                        centerIcon.isHidden = true
                        centerLabel.isHidden = false
                        centerLabel.text = "\(formatNumber(val))/\(formatNumber(maxVal))"
                    }
                }
            wrapper.storeCancellable(cancellable)

            let outerWrapper = UIView()
            outerWrapper.addSubview(container)
            container.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                container.centerXAnchor.constraint(equalTo: outerWrapper.centerXAnchor),
                container.topAnchor.constraint(equalTo: outerWrapper.topAnchor),
                container.bottomAnchor.constraint(equalTo: outerWrapper.bottomAnchor),
            ])

            wrapper.embed(outerWrapper)
            return wrapper
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-9 {
            return String(Int(rounded))
        }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
