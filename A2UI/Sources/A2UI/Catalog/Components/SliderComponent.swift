import UIKit
import Combine

/// A slider control with two-way data binding.
///
/// Parameters:
/// - `value`: Data binding definition for the numeric value.
///   Also accepts legacy `binding` (string path).
/// - `min`: Minimum value (default 0).
/// - `max`: Maximum value (default 100).
/// - `label`: Optional label text. Supports `stringReference` (data binding).
/// - `checks`: Array of `{condition, message}` for validation.
enum SliderComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Slider") { context in
            let wrapper = BindableView()
            let valueDef = BoundValueHelpers.readValueDef(from: context.data)
            let writablePath = BoundValueHelpers.extractWritablePath(valueDef)
            let minVal = (context.data["min"] as? NSNumber)?.floatValue ?? 0
            let maxVal = (context.data["max"] as? NSNumber)?.floatValue ?? 100
            let labelDef = context.data["label"]
            let checks = (context.data["checks"] as? [Any])?.compactMap { $0 as? JsonMap }

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 4
            wrapper.embed(stack)

            // Label (static or dynamic)
            let topLabel = UILabel()
            topLabel.font = .systemFont(ofSize: 13, weight: .medium)
            topLabel.textColor = .secondaryLabel
            topLabel.isHidden = true
            stack.addArrangedSubview(topLabel)

            if let staticText = labelDef as? String {
                topLabel.text = staticText
                topLabel.isHidden = false
            } else if labelDef is JsonMap {
                topLabel.isHidden = false
                let labelCancellable = BoundValueHelpers.resolveString(labelDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak topLabel] text in
                        topLabel?.text = text ?? ""
                    }
                wrapper.storeCancellable(labelCancellable)
            }

            let sliderStack = UIStackView()
            sliderStack.axis = .horizontal
            sliderStack.spacing = 8
            sliderStack.alignment = .center
            stack.addArrangedSubview(sliderStack)

            let slider = UISlider()
            slider.minimumValue = minVal
            slider.maximumValue = maxVal
            sliderStack.addArrangedSubview(slider)

            let valueLabel = UILabel()
            valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
            valueLabel.textColor = .secondaryLabel
            valueLabel.setContentHuggingPriority(.required, for: .horizontal)
            sliderStack.addArrangedSubview(valueLabel)

            let errorLabel = UILabel()
            errorLabel.font = .systemFont(ofSize: 12)
            errorLabel.textColor = .systemRed
            errorLabel.numberOfLines = 0
            errorLabel.isHidden = true
            stack.addArrangedSubview(errorLabel)

            if let valueDef = valueDef {
                var isUpdatingFromModel = false

                let cancellable = BoundValueHelpers.resolveNumber(valueDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak slider, weak valueLabel] value in
                        guard let slider = slider, let valueLabel = valueLabel else { return }
                        let numValue = Float(value ?? 0)
                        isUpdatingFromModel = true
                        slider.value = numValue
                        valueLabel.text = String(format: "%.0f", numValue)
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                if let path = writablePath {
                    let dataCtx = context.dataContext
                    slider.addAction(UIAction { [weak slider, weak valueLabel] _ in
                        guard !isUpdatingFromModel, let slider = slider else { return }
                        let val = Double(slider.value)
                        valueLabel?.text = String(format: "%.0f", val)
                        dataCtx.update(pathString: path, value: val)
                    }, for: .valueChanged)
                }
            }

            if let checks = checks, !checks.isEmpty {
                let validationCancellable = ValidationHelper.validateStream(checks: checks, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak errorLabel] errorMessage in
                        errorLabel?.text = errorMessage
                        errorLabel?.isHidden = (errorMessage == nil)
                    }
                wrapper.storeCancellable(validationCancellable)
            }

            return wrapper
        }
    }
}
