import UIKit
import Combine

/// A discrete tick slider with 5 divisions (6 tick positions).
///
/// Parameters:
/// - `value`: Number reference. Snapped to nearest tick.
/// - `max`: Number reference for maximum value.
enum TickSliderComponent {

    private static let divisionCount = 5
    private static let tickCount = divisionCount + 1
    private static let trackHeight: CGFloat = 6
    private static let trackRadius: CGFloat = 3
    private static let thumbSize: CGFloat = 24
    private static let tickSize: CGFloat = 4
    private static let trackColor = UIColor(red: 0xFF/255, green: 0x59/255, blue: 0x6C/255, alpha: 1)
    private static let tickColor = UIColor(red: 0x3C/255, green: 0x3C/255, blue: 0x43/255, alpha: 0.18)

    static func register() -> CatalogItem {
        CatalogItem(name: "TickSlider") { context in
            let wrapper = BindableView()
            let valueDef = context.data["value"]
            let maxDef = context.data["max"]
            let valuePath = (valueDef as? JsonMap)?["path"] as? String

            let container = UIStackView()
            container.axis = .vertical
            container.spacing = 12
            container.alignment = .fill
            wrapper.embed(container)

            // Preview number
            let previewLabel = UILabel()
            previewLabel.textAlignment = .center
            previewLabel.font = LabelComponent.resolveFont(variant: "title")
            previewLabel.font = .systemFont(ofSize: 36, weight: .semibold)
            previewLabel.textColor = MacaronColors.label
            container.addArrangedSubview(previewLabel)

            // Scale area
            let scaleRow = UIStackView()
            scaleRow.axis = .horizontal
            scaleRow.alignment = .center
            scaleRow.spacing = 12

            let minLabel = UILabel()
            minLabel.text = "0"
            minLabel.font = .systemFont(ofSize: 14, weight: .regular)
            minLabel.textColor = MacaronColors.label
            scaleRow.addArrangedSubview(minLabel)

            let sliderContainer = TickSliderTrackView()
            sliderContainer.translatesAutoresizingMaskIntoConstraints = false
            sliderContainer.heightAnchor.constraint(equalToConstant: 50).isActive = true
            sliderContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            sliderContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            scaleRow.addArrangedSubview(sliderContainer)

            let maxLabel = UILabel()
            maxLabel.font = .systemFont(ofSize: 14, weight: .regular)
            maxLabel.textColor = MacaronColors.label
            scaleRow.addArrangedSubview(maxLabel)

            container.addArrangedSubview(scaleRow)

            let dataCtx = context.dataContext

            let valuePub = BoundValueHelpers.resolveNumber(valueDef, context: dataCtx)
            let maxPub = BoundValueHelpers.resolveNumber(maxDef, context: dataCtx)

            let cancellable = valuePub.combineLatest(maxPub)
                .receive(on: DispatchQueue.main)
                .sink { [weak previewLabel, weak maxLabel, weak sliderContainer] rawValue, rawMax in
                    guard let previewLabel = previewLabel,
                          let maxLabel = maxLabel,
                          let slider = sliderContainer else { return }

                    let resolved = resolveTickSliderValue(rawValue: rawValue, rawMax: rawMax)
                    writeBackIfNeeded(
                        dataContext: dataCtx, path: valuePath,
                        rawValue: rawValue, snappedValue: resolved.snappedValue
                    )

                    previewLabel.text = formatNumber(resolved.snappedValue)
                    maxLabel.text = formatNumber(resolved.normalizedMax)
                    slider.ratio = resolved.ratio
                    slider.setNeedsLayout()
                }
            wrapper.storeCancellable(cancellable)

            // Gesture handling
            sliderContainer.onInteraction = { [weak sliderContainer] localX in
                guard let slider = sliderContainer, let path = valuePath else { return }
                let width = slider.bounds.width
                guard width > 0 else { return }

                let currentMax = BoundValueHelpers.resolveNumber(maxDef, context: dataCtx)
                var maxCancellable: AnyCancellable?
                maxCancellable = currentMax.first().sink { rawMax in
                    let normalizedMax = max(rawMax ?? 0, 0)
                    guard normalizedMax > 0 else { return }
                    let ratio = min(max(localX / width, 0), 1)
                    let snappedIndex = Int((ratio * CGFloat(divisionCount)).rounded())
                        .clamped(to: 0...divisionCount)
                    let step = normalizedMax / Double(divisionCount)
                    let nextValue = min(step * Double(snappedIndex), normalizedMax)
                    dataCtx.update(pathString: path, value: nextValue)
                    _ = maxCancellable
                }
            }

            return wrapper
        }
    }

    // MARK: - Value Resolution

    private struct ResolvedValue {
        let normalizedMax: Double
        let snappedValue: Double
        let snappedIndex: Int
        var ratio: CGFloat { CGFloat(snappedIndex) / CGFloat(divisionCount) }
    }

    private static func resolveTickSliderValue(rawValue: Double?, rawMax: Double?) -> ResolvedValue {
        let normalizedMax = max(rawMax ?? 0, 0)
        guard normalizedMax > 0 else {
            return ResolvedValue(normalizedMax: 0, snappedValue: 0, snappedIndex: 0)
        }
        let clamped = min(max(rawValue ?? 0, 0), normalizedMax)
        let step = normalizedMax / Double(divisionCount)
        let snappedIndex = Int((clamped / step).rounded()).clamped(to: 0...divisionCount)
        let snappedValue = min(step * Double(snappedIndex), normalizedMax)
        return ResolvedValue(normalizedMax: normalizedMax, snappedValue: snappedValue, snappedIndex: snappedIndex)
    }

    private static func writeBackIfNeeded(
        dataContext: DataContext, path: String?,
        rawValue: Double?, snappedValue: Double
    ) {
        guard let path = path, !path.isEmpty else { return }
        let current = rawValue ?? 0
        guard abs(current - snappedValue) > 0.000001 else { return }
        dataContext.update(pathString: path, value: snappedValue)
    }

    private static func formatNumber(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let rounded = value.rounded()
        if abs(value - rounded) < 1e-9 { return String(Int(rounded)) }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.isEmpty ? "0" : text
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Track View

private final class TickSliderTrackView: UIView {
    var ratio: CGFloat = 0
    var onInteraction: ((CGFloat) -> Void)?

    private let trackLayer = CALayer()
    private let thumbLayer = CALayer()
    private var tickLayers: [CALayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        trackLayer.backgroundColor = UIColor(red: 0xFF/255, green: 0x59/255, blue: 0x6C/255, alpha: 1).cgColor
        trackLayer.cornerRadius = 3
        layer.addSublayer(trackLayer)

        for _ in 0..<6 {
            let tick = CALayer()
            tick.backgroundColor = UIColor(red: 0x3C/255, green: 0x3C/255, blue: 0x43/255, alpha: 0.18).cgColor
            tick.cornerRadius = 2
            layer.addSublayer(tick)
            tickLayers.append(tick)
        }

        thumbLayer.backgroundColor = UIColor.white.cgColor
        thumbLayer.cornerRadius = 12
        thumbLayer.shadowColor = UIColor.black.cgColor
        thumbLayer.shadowOffset = CGSize(width: 0, height: 6)
        thumbLayer.shadowRadius = 13
        thumbLayer.shadowOpacity = 0.12
        layer.addSublayer(thumbLayer)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let trackTop: CGFloat = 12
        let trackHeight: CGFloat = 6

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        trackLayer.frame = CGRect(x: 0, y: trackTop, width: w, height: trackHeight)

        for (i, tick) in tickLayers.enumerated() {
            let x = w * CGFloat(i) / 5.0 - 2
            tick.frame = CGRect(x: x, y: 28, width: 4, height: 4)
        }

        let thumbX = w * ratio - 12
        thumbLayer.frame = CGRect(x: thumbX, y: trackTop - 9, width: 24, height: 24)

        CATransaction.commit()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let x = gesture.location(in: self).x
        onInteraction?(x)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let x = gesture.location(in: self).x
        onInteraction?(x)
    }
}
