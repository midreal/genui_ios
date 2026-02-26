import UIKit
import Combine

/// A boolean toggle (UISwitch) with two-way data binding.
///
/// Parameters:
/// - `value`: Data binding definition for the boolean value.
///   Also accepts legacy `binding` (string path).
/// - `label`: Optional text label. Supports `stringReference` (data binding).
/// - `checks`: Array of `{condition, message}` for validation.
enum CheckBoxComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "CheckBox") { context in
            let wrapper = BindableView()
            let valueDef = BoundValueHelpers.readValueDef(from: context.data)
            let writablePath = BoundValueHelpers.extractWritablePath(valueDef)
            let labelDef = context.data["label"]
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

            let label = UILabel()
            label.font = .systemFont(ofSize: 15)
            label.numberOfLines = 0

            if let staticText = labelDef as? String {
                label.text = staticText
                stack.addArrangedSubview(label)
            } else if labelDef is JsonMap {
                stack.addArrangedSubview(label)
                let labelCancellable = BoundValueHelpers.resolveString(labelDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak label] text in
                        label?.text = text ?? ""
                    }
                wrapper.storeCancellable(labelCancellable)
            }

            let errorLabel = UILabel()
            errorLabel.font = .systemFont(ofSize: 12)
            errorLabel.textColor = .systemRed
            errorLabel.numberOfLines = 0
            errorLabel.isHidden = true
            outerStack.addArrangedSubview(errorLabel)

            if let valueDef = valueDef {
                var isUpdatingFromModel = false

                let cancellable = BoundValueHelpers.resolveBool(valueDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak toggle] value in
                        guard let toggle = toggle else { return }
                        isUpdatingFromModel = true
                        toggle.isOn = value ?? false
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                if let path = writablePath {
                    let dataCtx = context.dataContext
                    toggle.addAction(UIAction { [weak toggle] _ in
                        guard !isUpdatingFromModel, let toggle = toggle else { return }
                        dataCtx.update(pathString: path, value: toggle.isOn)
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
