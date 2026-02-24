import UIKit
import Combine

/// A text input field with two-way data binding.
///
/// Parameters:
/// - `binding`: Data path for two-way binding (e.g. "/search/query").
/// - `label`: Placeholder label text.
/// - `multiline`: Whether to use a multiline text view.
enum TextFieldComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "TextField", isImplicitlyFlexible: true) { context in
            let wrapper = BindableView()
            let bindingPath = context.data["binding"] as? String
            let label = context.data["label"] as? String ?? ""
            let multiline = context.data["multiline"] as? Bool ?? false

            if multiline {
                return buildMultiline(context: context, wrapper: wrapper, bindingPath: bindingPath, placeholder: label)
            }

            let textField = UITextField()
            textField.placeholder = label
            textField.borderStyle = .roundedRect
            textField.font = .systemFont(ofSize: 15)
            textField.translatesAutoresizingMaskIntoConstraints = false
            wrapper.embed(textField)

            if let path = bindingPath {
                var isUpdatingFromModel = false

                let cancellable = context.dataContext.subscribe(pathString: path)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak textField] value in
                        guard let textField = textField, !textField.isFirstResponder else {
                            if !isUpdatingFromModel {
                                isUpdatingFromModel = true
                                textField?.text = value as? String ?? ""
                                isUpdatingFromModel = false
                            }
                            return
                        }
                        isUpdatingFromModel = true
                        textField.text = value as? String ?? ""
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                let dataCtx = context.dataContext
                textField.addAction(UIAction { [weak textField] _ in
                    guard !isUpdatingFromModel else { return }
                    dataCtx.update(pathString: path, value: textField?.text)
                }, for: .editingChanged)
            }

            return wrapper
        }
    }

    private static func buildMultiline(
        context: CatalogItemContext,
        wrapper: BindableView,
        bindingPath: String?,
        placeholder: String
    ) -> UIView {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 15)
        textView.isScrollEnabled = false
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.borderWidth = 0.5
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        wrapper.embed(textView)

        if let path = bindingPath {
            let cancellable = context.dataContext.subscribe(pathString: path)
                .receive(on: DispatchQueue.main)
                .sink { [weak textView] value in
                    guard let textView = textView, !textView.isFirstResponder else { return }
                    textView.text = value as? String ?? ""
                }
            wrapper.storeCancellable(cancellable)
        }

        return wrapper
    }
}
