import UIKit
import Combine

/// A slider control with two-way data binding.
///
/// Parameters:
/// - `binding`: Data path for the numeric value.
/// - `min`: Minimum value (default 0).
/// - `max`: Maximum value (default 100).
/// - `label`: Optional label text.
/// - `checks`: Array of `{condition, message}` for validation.
enum SliderComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Slider") { context in
            let wrapper = BindableView()
            let bindingPath = context.data["binding"] as? String
            let minVal = (context.data["min"] as? NSNumber)?.floatValue ?? 0
            let maxVal = (context.data["max"] as? NSNumber)?.floatValue ?? 100
            let labelText = context.data["label"] as? String
            let checks = (context.data["checks"] as? [Any])?.compactMap { $0 as? JsonMap }

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 4
            wrapper.embed(stack)

            if let text = labelText {
                let label = UILabel()
                label.text = text
                label.font = .systemFont(ofSize: 13, weight: .medium)
                label.textColor = .secondaryLabel
                stack.addArrangedSubview(label)
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

            if let path = bindingPath {
                var isUpdatingFromModel = false

                let cancellable = context.dataContext.subscribe(pathString: path)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak slider, weak valueLabel] value in
                        guard let slider = slider, let valueLabel = valueLabel else { return }
                        let numValue = (value as? NSNumber)?.floatValue ?? 0
                        isUpdatingFromModel = true
                        slider.value = numValue
                        valueLabel.text = String(format: "%.0f", numValue)
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                let dataCtx = context.dataContext
                slider.addAction(UIAction { [weak slider, weak valueLabel] _ in
                    guard !isUpdatingFromModel, let slider = slider else { return }
                    let val = Double(slider.value)
                    valueLabel?.text = String(format: "%.0f", val)
                    dataCtx.update(pathString: path, value: val)
                }, for: .valueChanged)
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
