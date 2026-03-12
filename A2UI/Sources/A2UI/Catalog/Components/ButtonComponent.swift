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
            let variant = context.data["variant"] as? String
                ?? context.data["style"] as? String ?? ""
            let config = makeConfiguration(variant: variant)

            // Inject macaron button scope so Label descendants can adapt
            let scopeStyle: MacaronButtonStyle = switch variant {
            case "primary": .primary
            case "secondary": .secondary
            case "plain": .plain
            default: .primary
            }
            wrapper.macaronScope.buttonStyle = scopeStyle
            let button = UIButton(configuration: config)
            button.translatesAutoresizingMaskIntoConstraints = false

            if let childId = context.data["child"] as? String {
                if let childComp = context.getComponent(childId),
                   childComp.type == "Text" {
                    let textValue = childComp.properties["text"]
                    let cancellable = context.dataContext.resolve(textValue)
                        .receive(on: DispatchQueue.main)
                        .sink { [weak button] value in
                            guard let button = button else { return }
                            let text = (value as? String) ?? "\(value ?? "")"
                            if TextComponent.containsMarkdown(text) {
                                let rendered = TextComponent.renderMarkdown(text, variant: "body")
                                button.configuration?.attributedTitle = AttributedString(rendered)
                            } else {
                                button.configuration?.title = text
                            }
                        }
                    wrapper.storeCancellable(cancellable)
                } else {
                    let childView = context.buildChild(childId, nil)
                    childView.isUserInteractionEnabled = false
                    button.addSubview(childView)
                    childView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        childView.topAnchor.constraint(equalTo: button.topAnchor, constant: 10),
                        childView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -10),
                        childView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 20),
                        childView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -20),
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
                    }
                wrapper.storeCancellable(cancellable)
            }

            return wrapper
        }
    }

    private static func makeConfiguration(variant: String) -> UIButton.Configuration {
        let insets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        switch variant {
        case "primary":
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = .systemBlue
            config.baseForegroundColor = .white
            config.cornerStyle = .medium
            config.contentInsets = insets
            return config
        case "secondary":
            var config = UIButton.Configuration.plain()
            config.baseForegroundColor = .label
            config.background.strokeColor = MacaronColors.cardBorder
            config.background.strokeWidth = 0.5
            config.cornerStyle = .capsule
            config.contentInsets = insets
            return config
        case "plain":
            var config = UIButton.Configuration.plain()
            config.baseForegroundColor = .label
            config.contentInsets = insets
            return config
        case "borderless":
            var config = UIButton.Configuration.plain()
            config.baseForegroundColor = .systemBlue
            config.contentInsets = insets
            return config
        default:
            var config = UIButton.Configuration.gray()
            config.baseForegroundColor = .label
            config.cornerStyle = .medium
            config.contentInsets = insets
            return config
        }
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
