import UIKit
import Combine

/// A six-slot numeric password keypad with built-in submit behavior.
///
/// Parameters:
/// - `value`: Object with `path` for storing keypad input.
/// - `action`: Action emitted by ENT and auto-submit. Runtime injects context
///   fields: value, length, trigger.
enum PasswordKeypadComponent {

    private static let maxDigits = 6
    private static let cardColor = UIColor(red: 0x29/255, green: 0x27/255, blue: 0x24/255, alpha: 1)
    private static let displayColor = UIColor.black
    private static let keyColor = UIColor.white
    private static let digitColor = MacaronColors.label
    private static let deleteColor = UIColor(red: 0xF6/255, green: 0x3B/255, blue: 0x39/255, alpha: 1)
    private static let enterColor = MacaronColors.selectionActive
    private static let displayTextColor = UIColor.white

    static func register() -> CatalogItem {
        CatalogItem(name: "PasswordKeypad") { context in
            let wrapper = BindableView()

            let valuePath = (context.data["value"] as? JsonMap)?["path"] as? String ?? ""
            let action = context.data["action"] as? JsonMap ?? [:]
            let actionName = action["name"] as? String ?? ""
            let contextDefinition = action["context"] as? [Any] ?? []

            // Clear initial value
            if !valuePath.isEmpty {
                context.dataContext.update(pathString: valuePath, value: "")
            }

            let cardView = UIView()
            cardView.backgroundColor = cardColor
            cardView.layer.cornerRadius = 16
            cardView.clipsToBounds = true
            wrapper.embed(cardView, insets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))

            let mainStack = UIStackView()
            mainStack.axis = .vertical
            mainStack.spacing = 12
            mainStack.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview(mainStack)
            NSLayoutConstraint.activate([
                mainStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
                mainStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
                mainStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
                mainStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            ])

            // Display panel
            let displayView = UIView()
            displayView.backgroundColor = displayColor
            displayView.layer.cornerRadius = 12
            displayView.clipsToBounds = true
            displayView.translatesAutoresizingMaskIntoConstraints = false
            displayView.heightAnchor.constraint(equalToConstant: 80).isActive = true

            let slotStack = UIStackView()
            slotStack.axis = .horizontal
            slotStack.distribution = .fillEqually
            slotStack.translatesAutoresizingMaskIntoConstraints = false
            displayView.addSubview(slotStack)
            NSLayoutConstraint.activate([
                slotStack.topAnchor.constraint(equalTo: displayView.topAnchor, constant: 24),
                slotStack.bottomAnchor.constraint(equalTo: displayView.bottomAnchor, constant: -24),
                slotStack.leadingAnchor.constraint(equalTo: displayView.leadingAnchor, constant: 28),
                slotStack.trailingAnchor.constraint(equalTo: displayView.trailingAnchor, constant: -28),
            ])

            var slotLabels: [UILabel] = []
            for _ in 0..<maxDigits {
                let slotLabel = UILabel()
                slotLabel.text = "_"
                slotLabel.textAlignment = .center
                slotLabel.font = .systemFont(ofSize: 20, weight: .semibold)
                slotLabel.textColor = displayTextColor
                slotStack.addArrangedSubview(slotLabel)
                slotLabels.append(slotLabel)
            }

            mainStack.addArrangedSubview(displayView)

            // Keyboard panel
            let keyLayout: [[KeySpec]] = [
                [.digit("1"), .digit("2"), .digit("3")],
                [.digit("4"), .digit("5"), .digit("6")],
                [.digit("7"), .digit("8"), .digit("9")],
                [.delete, .digit("0"), .enter],
            ]

            let keyboardStack = UIStackView()
            keyboardStack.axis = .vertical
            keyboardStack.spacing = 12

            var currentValue = ""

            func updateDisplay() {
                for i in 0..<maxDigits {
                    slotLabels[i].text = i < currentValue.count
                        ? String(currentValue[currentValue.index(currentValue.startIndex, offsetBy: i)])
                        : "_"
                }
            }

            func dispatchAction(trigger: String) {
                guard !actionName.isEmpty else { return }
                var resolvedContext: JsonMap = [:]
                resolvedContext["value"] = currentValue
                resolvedContext["length"] = currentValue.count
                resolvedContext["trigger"] = trigger

                let event = UiEvent(data: [
                    "name": actionName,
                    "sourceComponentId": context.id,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "context": resolvedContext,
                ])
                context.dispatchEvent(event)
            }

            func handleKeyPress(_ spec: KeySpec) {
                switch spec {
                case .digit(let d):
                    guard currentValue.count < maxDigits else { return }
                    currentValue += d
                    if !valuePath.isEmpty {
                        context.dataContext.update(pathString: valuePath, value: currentValue)
                    }
                    updateDisplay()
                    if currentValue.count == maxDigits {
                        dispatchAction(trigger: "auto")
                    }
                case .delete:
                    guard !currentValue.isEmpty else { return }
                    currentValue.removeLast()
                    if !valuePath.isEmpty {
                        context.dataContext.update(pathString: valuePath, value: currentValue)
                    }
                    updateDisplay()
                case .enter:
                    guard !currentValue.isEmpty else { return }
                    dispatchAction(trigger: "enter")
                }
            }

            for row in keyLayout {
                let rowStack = UIStackView()
                rowStack.axis = .horizontal
                rowStack.spacing = 12
                rowStack.distribution = .fillEqually

                for spec in row {
                    let keyButton = KeypadButton(spec: spec) {
                        handleKeyPress(spec)
                    }
                    keyButton.translatesAutoresizingMaskIntoConstraints = false
                    keyButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
                    rowStack.addArrangedSubview(keyButton)
                }

                keyboardStack.addArrangedSubview(rowStack)
            }

            mainStack.addArrangedSubview(keyboardStack)

            return wrapper
        }
    }
}

private enum KeySpec {
    case digit(String)
    case delete
    case enter
}

private final class KeypadButton: UIControl {
    private let label = UILabel()
    private var onPress: (() -> Void)?

    init(spec: KeySpec, onPress: @escaping () -> Void) {
        self.onPress = onPress
        super.init(frame: .zero)

        backgroundColor = .white
        layer.cornerRadius = 8
        clipsToBounds = true

        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        switch spec {
        case .digit(let d):
            label.text = d
            label.font = .systemFont(ofSize: 20, weight: .semibold)
            label.textColor = MacaronColors.label
        case .delete:
            label.text = "DEL"
            label.font = UIFont(name: "NotoSerif", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)
            label.textColor = UIColor(red: 0xF6/255, green: 0x3B/255, blue: 0x39/255, alpha: 1)
        case .enter:
            label.text = "ENT"
            label.font = UIFont(name: "NotoSerif", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)
            label.textColor = MacaronColors.selectionActive
        }

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        addTarget(self, action: #selector(handleDown), for: .touchDown)
        addTarget(self, action: #selector(handleUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    @objc private func handleTap() {
        onPress?()
    }

    @objc private func handleDown() {
        UIView.animate(withDuration: 0.09, delay: 0, options: .curveEaseOut) {
            self.transform = CGAffineTransform(translationX: 0, y: 2)
        }
    }

    @objc private func handleUp() {
        UIView.animate(withDuration: 0.16, delay: 0, options: .curveEaseOut) {
            self.transform = .identity
        }
    }
}
