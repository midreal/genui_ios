import UIKit
import Combine

/// An interactive button that triggers an action when pressed.
///
/// Parameters:
/// - `child`: The ID of a child component (usually Text).
/// - `action`: The action to perform — `{"event": {"name": "..."}}` or `{"functionCall": {...}}`.
/// - `variant`: Style hint — "primary" or "borderless".
/// - `checks`: Array of `{condition, message}` for enabling/disabling the button.
enum ButtonComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Button") { context in
            let wrapper = BindableView()
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false

            let variant = context.data["variant"] as? String ?? ""
            configureStyle(button, variant: variant)

            if let childId = context.data["child"] as? String {
                let childView = context.buildChild(childId, nil)
                if let label = findLabel(in: childView) {
                    button.setTitle(label.text, for: .normal)
                    if let attrText = label.attributedText {
                        button.setAttributedTitle(attrText, for: .normal)
                    }
                } else {
                    button.addSubview(childView)
                    childView.translatesAutoresizingMaskIntoConstraints = false
                    childView.isUserInteractionEnabled = false
                    NSLayoutConstraint.activate([
                        childView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                        childView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                    ])
                }
            }

            let action = context.data["action"] as? JsonMap
            let componentId = context.id
            let dispatch = context.dispatchEvent
            let dataCtx = context.dataContext

            let reportErr = context.reportError
            button.addAction(UIAction { [weak wrapper] _ in
                handlePress(
                    action: action, componentId: componentId,
                    dispatch: dispatch, dataContext: dataCtx,
                    reportError: reportErr, sourceView: wrapper
                )
            }, for: .touchUpInside)

            wrapper.embed(button)

            let checks = (context.data["checks"] as? [Any])?.compactMap { $0 as? JsonMap }
            if let checks = checks, !checks.isEmpty {
                let cancellable = ValidationHelper.validateStream(checks: checks, context: dataCtx)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak button] errorMessage in
                        button?.isEnabled = (errorMessage == nil)
                        button?.alpha = (errorMessage == nil) ? 1.0 : 0.5
                    }
                wrapper.storeCancellable(cancellable)
            }

            return wrapper
        }
    }

    private static func configureStyle(_ button: UIButton, variant: String) {
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        button.layer.cornerRadius = 8
        button.clipsToBounds = true

        switch variant {
        case "primary":
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        case "borderless":
            button.backgroundColor = .clear
            button.setTitleColor(.systemBlue, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        default:
            button.backgroundColor = .secondarySystemBackground
            button.setTitleColor(.label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        }
    }

    private static func findLabel(in view: UIView) -> UILabel? {
        if let label = view as? UILabel { return label }
        if let wrapper = view as? BindableView {
            for sub in wrapper.subviews {
                if let label = findLabel(in: sub) { return label }
            }
        }
        for sub in view.subviews {
            if let label = findLabel(in: sub) { return label }
        }
        return nil
    }

    private static func handlePress(
        action: JsonMap?,
        componentId: String,
        dispatch: @escaping DispatchEventCallback,
        dataContext: DataContext,
        reportError: ((Error) -> Void)? = nil,
        sourceView: UIView? = nil
    ) {
        guard let action = action else {
            #if DEBUG
            print("[A2UI] Button \(componentId): action is nil, nothing to do")
            #endif
            return
        }

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
            if let callName = funcMap["call"] as? String, callName == "closeModal" {
                DispatchQueue.main.async {
                    if let view = sourceView {
                        var responder: UIResponder? = view
                        while let next = responder?.next {
                            if let vc = next as? UIViewController, vc.presentingViewController != nil {
                                vc.dismiss(animated: true)
                                return
                            }
                            responder = next
                        }
                    }
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let topVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController?.presentedViewController {
                        topVC.dismiss(animated: true)
                    }
                }
                return
            }
            var cancellable: AnyCancellable?
            cancellable = dataContext.resolve(funcMap)
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { _ in
                    _ = cancellable
                })
        } else {
            #if DEBUG
            print("[A2UI] Button \(componentId): action has neither 'event' nor 'functionCall'")
            #endif
        }
    }
}
