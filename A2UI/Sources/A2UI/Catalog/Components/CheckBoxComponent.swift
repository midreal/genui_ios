import UIKit
import Combine

/// A boolean toggle (UISwitch) with two-way data binding.
///
/// Parameters:
/// - `binding`: Data path for the boolean value.
/// - `label`: Optional text label displayed beside the switch.
/// - `checks`: Array of `{condition, message}` for validation.
enum CheckBoxComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "CheckBox", isImplicitlyFlexible: true) { context in
            let wrapper = BindableView()
            let bindingPath = context.data["binding"] as? String
            let labelText = context.data["label"] as? String
            let checks = (context.data["checks"] as? [Any])?.compactMap { $0 as? JsonMap }

            let outerStack = UIStackView()
            outerStack.axis = .vertical
            outerStack.spacing = 4
            wrapper.embed(outerStack)

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 12
            stack.alignment = .center
            outerStack.addArrangedSubview(stack)

            let toggle = UISwitch()
            stack.addArrangedSubview(toggle)

            if let text = labelText {
                let label = UILabel()
                label.text = text
                label.font = .systemFont(ofSize: 15)
                stack.addArrangedSubview(label)
            }

            let errorLabel = UILabel()
            errorLabel.font = .systemFont(ofSize: 12)
            errorLabel.textColor = .systemRed
            errorLabel.numberOfLines = 0
            errorLabel.isHidden = true
            outerStack.addArrangedSubview(errorLabel)

            if let path = bindingPath {
                var isUpdatingFromModel = false

                let cancellable = context.dataContext.subscribe(pathString: path)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak toggle] value in
                        guard let toggle = toggle else { return }
                        isUpdatingFromModel = true
                        toggle.isOn = value as? Bool ?? false
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                let dataCtx = context.dataContext
                toggle.addAction(UIAction { [weak toggle] _ in
                    guard !isUpdatingFromModel, let toggle = toggle else { return }
                    dataCtx.update(pathString: path, value: toggle.isOn)
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
