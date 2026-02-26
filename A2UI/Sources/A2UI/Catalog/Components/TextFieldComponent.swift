import UIKit
import Combine

/// A text input field with two-way data binding.
///
/// Parameters:
/// - `value`: Data binding definition (literal, `{path: "..."}`, or `{call: ...}`).
///   Also accepts legacy `binding` (string path) for backward compatibility.
/// - `label`: Label/placeholder text. Supports `stringReference` (data binding).
/// - `variant`: `"shortText"`, `"longText"`, `"number"`, `"obscured"`.
/// - `checks`: Array of `{condition, message}` for validation.
/// - `validationRegexp`: A regex pattern to validate input.
/// - `onSubmittedAction`: Action to perform on submit (event / functionCall / closeModal).
enum TextFieldComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "TextField", isImplicitlyFlexible: true) { context in
            let wrapper = BindableView()
            let valueDef = BoundValueHelpers.readValueDef(from: context.data)
            let writablePath = BoundValueHelpers.extractWritablePath(valueDef)
            let labelDef = context.data["label"]
            let variant = context.data["variant"] as? String ?? "shortText"
            let checks = (context.data["checks"] as? [Any])?.compactMap { $0 as? JsonMap }
            let validationRegexp = context.data["validationRegexp"] as? String
            let onSubmittedAction = context.data["onSubmittedAction"] as? JsonMap

            let isMultiline = variant == "longText"

            if isMultiline {
                return buildMultiline(
                    context: context, wrapper: wrapper,
                    valueDef: valueDef, writablePath: writablePath,
                    labelDef: labelDef, checks: checks
                )
            }

            let textField = UITextField()
            textField.borderStyle = .roundedRect
            textField.font = .systemFont(ofSize: 15)
            textField.translatesAutoresizingMaskIntoConstraints = false

            // Static label fallback
            if let staticLabel = labelDef as? String {
                textField.placeholder = staticLabel
            }

            switch variant {
            case "number":
                textField.keyboardType = .decimalPad
            case "obscured":
                textField.isSecureTextEntry = true
            default:
                textField.keyboardType = .default
            }

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 4
            wrapper.embed(stack)
            stack.addArrangedSubview(textField)

            let errorLabel = UILabel()
            errorLabel.font = .systemFont(ofSize: 12)
            errorLabel.textColor = .systemRed
            errorLabel.numberOfLines = 0
            errorLabel.isHidden = true
            stack.addArrangedSubview(errorLabel)

            // Dynamic label binding
            if labelDef is JsonMap {
                let labelCancellable = BoundValueHelpers.resolveString(labelDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak textField] text in
                        textField?.placeholder = text ?? ""
                    }
                wrapper.storeCancellable(labelCancellable)
            }

            // Two-way value binding
            if let valueDef = valueDef {
                var isUpdatingFromModel = false

                let cancellable = BoundValueHelpers.resolveString(valueDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak textField] value in
                        guard let textField = textField else { return }
                        guard !textField.isFirstResponder else { return }
                        isUpdatingFromModel = true
                        textField.text = value ?? ""
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                if let path = writablePath {
                    let dataCtx = context.dataContext
                    let componentId = context.id
                    let dispatch = context.dispatchEvent

                    textField.addAction(UIAction { [weak textField] _ in
                        guard !isUpdatingFromModel else { return }
                        let newValue = textField?.text ?? ""
                        if variant == "number", let num = Double(newValue) {
                            dataCtx.update(pathString: path, value: num)
                        } else {
                            dataCtx.update(pathString: path, value: newValue)
                        }

                        if let pattern = validationRegexp {
                            let regex = try? NSRegularExpression(pattern: pattern)
                            let range = NSRange(newValue.startIndex..., in: newValue)
                            let valid = regex?.firstMatch(in: newValue, range: range) != nil
                            errorLabel.text = valid ? nil : "Invalid format"
                            errorLabel.isHidden = valid
                        }
                    }, for: .editingChanged)

                    if let submitAction = onSubmittedAction {
                        textField.addAction(UIAction { _ in
                            ButtonComponent.triggerAction(
                                action: submitAction, componentId: componentId,
                                dispatch: dispatch, dataContext: dataCtx,
                                sourceView: wrapper
                            )
                        }, for: .editingDidEndOnExit)
                    }
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

    private static func buildMultiline(
        context: CatalogItemContext,
        wrapper: BindableView,
        valueDef: Any?,
        writablePath: String?,
        labelDef: Any?,
        checks: [JsonMap]?
    ) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        wrapper.embed(stack)

        // Optional label above the text view
        let topLabel = UILabel()
        topLabel.font = .systemFont(ofSize: 13, weight: .medium)
        topLabel.textColor = .secondaryLabel
        topLabel.isHidden = true
        stack.addArrangedSubview(topLabel)

        if let staticLabel = labelDef as? String {
            topLabel.text = staticLabel
            topLabel.isHidden = false
        } else if labelDef is JsonMap {
            let labelCancellable = BoundValueHelpers.resolveString(labelDef, context: context.dataContext)
                .receive(on: DispatchQueue.main)
                .sink { [weak topLabel] text in
                    topLabel?.text = text
                    topLabel?.isHidden = (text == nil || text?.isEmpty == true)
                }
            wrapper.storeCancellable(labelCancellable)
        }

        let textView = UITextView()
        textView.font = .systemFont(ofSize: 15)
        textView.isScrollEnabled = false
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 0.5
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        stack.addArrangedSubview(textView)

        let errorLabel = UILabel()
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        stack.addArrangedSubview(errorLabel)

        if let valueDef = valueDef {
            let cancellable = BoundValueHelpers.resolveString(valueDef, context: context.dataContext)
                .receive(on: DispatchQueue.main)
                .sink { [weak textView] value in
                    guard let textView = textView, !textView.isFirstResponder else { return }
                    textView.text = value ?? ""
                }
            wrapper.storeCancellable(cancellable)
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

extension ButtonComponent {
    /// Shared action handler for Button and TextField onSubmittedAction.
    /// Supports `event`, `functionCall`, and `closeModal`.
    static func triggerAction(
        action: JsonMap,
        componentId: String,
        dispatch: @escaping DispatchEventCallback,
        dataContext: DataContext,
        sourceView: UIView? = nil
    ) {
        if let eventMap = action["event"] as? JsonMap,
           let name = eventMap["name"] as? String {
            let contextDefinition = eventMap["context"] as? JsonMap
            var cancellable: AnyCancellable?
            cancellable = ContextResolver.resolveContext(dataContext, contextDefinition)
                .receive(on: DispatchQueue.main)
                .sink { resolvedContext in
                    let event = UiEvent(data: [
                        "name": name,
                        "sourceComponentId": componentId,
                        "timestamp": ISO8601DateFormatter().string(from: Date()),
                        "context": resolvedContext
                    ])
                    dispatch(event)
                    _ = cancellable
                }
        } else if let funcMap = action["functionCall"] as? JsonMap {
            if funcMap["call"] as? String == "closeModal" {
                DispatchQueue.main.async {
                    var responder: UIResponder? = sourceView
                    while let next = responder?.next {
                        if let vc = next as? UIViewController, vc.presentingViewController != nil {
                            vc.dismiss(animated: true)
                            return
                        }
                        responder = next
                    }
                }
            } else {
                _ = dataContext.resolve(funcMap)
            }
        }
    }
}
