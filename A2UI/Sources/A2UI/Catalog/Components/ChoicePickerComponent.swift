import UIKit
import Combine

/// A selection component supporting single/multi-select with various display styles.
///
/// Parameters:
/// - `value`: Data binding definition for the selected value(s).
///   Also accepts legacy `binding` (string path).
/// - `options`: Array of `{"label": "...", "value": "..."}`, or a data binding
///   reference `{path: "..."}` for dynamic options.
/// - `label`: Optional group label. Supports `stringReference` (data binding).
/// - `variant`: `"mutuallyExclusive"` (radio) or `"multipleSelection"` (default).
/// - `displayStyle`: `"checkbox"` (default) or `"chips"`.
/// - `filterable`: Whether to show a search/filter field.
/// - `checks`: Array of `{condition, message}` for validation.
enum ChoicePickerComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "ChoicePicker", isImplicitlyFlexible: true) { context in
            let wrapper = BindableView()
            let valueDef = BoundValueHelpers.readValueDef(from: context.data)
            let writablePath = BoundValueHelpers.extractWritablePath(valueDef)
            let labelDef = context.data["label"]
            let optionsDef = context.data["options"]
            let variant = context.data["variant"] as? String ?? "multipleSelection"
            let displayStyle = context.data["displayStyle"] as? String ?? "checkbox"
            let filterable = context.data["filterable"] as? Bool ?? false
            let checks = (context.data["checks"] as? [Any])?.compactMap { $0 as? JsonMap }

            let isMutuallyExclusive = variant == "mutuallyExclusive"
            let isChips = displayStyle == "chips"

            let outerStack = UIStackView()
            outerStack.axis = .vertical
            outerStack.spacing = 8
            wrapper.embed(outerStack)

            // Label (static or dynamic)
            let topLabel = UILabel()
            topLabel.font = .systemFont(ofSize: 15, weight: .medium)
            topLabel.textColor = .secondaryLabel
            topLabel.isHidden = true
            outerStack.addArrangedSubview(topLabel)

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

            var filterText = ""
            let optionsContainer = UIStackView()

            if filterable {
                let filterField = UITextField()
                filterField.placeholder = "Filter options"
                filterField.borderStyle = .roundedRect
                filterField.font = .systemFont(ofSize: 14)
                outerStack.addArrangedSubview(filterField)

                filterField.addAction(UIAction { [weak filterField, weak optionsContainer] _ in
                    filterText = filterField?.text ?? ""
                    guard let container = optionsContainer else { return }
                    let selections = currentSelections(writablePath: writablePath, dataContext: context.dataContext)
                    rebuildOptions(
                        container: container, options: resolvedStaticOptions(optionsDef),
                        selectedValues: selections, filterText: filterText,
                        isMutuallyExclusive: isMutuallyExclusive, isChips: isChips,
                        writablePath: writablePath, dataContext: context.dataContext
                    )
                }, for: .editingChanged)
            }

            if isChips {
                optionsContainer.axis = .horizontal
                optionsContainer.spacing = 8
                optionsContainer.alignment = .center
                optionsContainer.distribution = .fill

                let scrollView = UIScrollView()
                scrollView.showsHorizontalScrollIndicator = false
                scrollView.addSubview(optionsContainer)
                optionsContainer.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    optionsContainer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                    optionsContainer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                    optionsContainer.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                    optionsContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                    optionsContainer.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
                ])
                scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
                outerStack.addArrangedSubview(scrollView)
            } else {
                optionsContainer.axis = .vertical
                optionsContainer.spacing = 2
                outerStack.addArrangedSubview(optionsContainer)
            }

            let errorLabel = UILabel()
            errorLabel.font = .systemFont(ofSize: 12)
            errorLabel.textColor = .systemRed
            errorLabel.numberOfLines = 0
            errorLabel.isHidden = true
            outerStack.addArrangedSubview(errorLabel)

            // Dynamic options via data binding
            if let optionsMap = optionsDef as? JsonMap, (optionsMap["path"] != nil || optionsMap["call"] != nil) {
                let optionsCancellable = BoundValueHelpers.resolveAny(optionsDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak optionsContainer] value in
                        guard let container = optionsContainer else { return }
                        let opts = (value as? [JsonMap]) ?? []
                        let selections = currentSelections(writablePath: writablePath, dataContext: context.dataContext)
                        rebuildOptions(
                            container: container, options: opts,
                            selectedValues: selections, filterText: filterText,
                            isMutuallyExclusive: isMutuallyExclusive, isChips: isChips,
                            writablePath: writablePath, dataContext: context.dataContext
                        )
                    }
                wrapper.storeCancellable(optionsCancellable)
            }

            // Subscribe to value changes to refresh selection state
            if let valueDef = valueDef {
                let cancellable = BoundValueHelpers.resolveAny(valueDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak optionsContainer] _ in
                        guard let container = optionsContainer else { return }
                        let opts: [JsonMap]
                        if let optionsMap = optionsDef as? JsonMap, (optionsMap["path"] != nil || optionsMap["call"] != nil) {
                            return // dynamic options handle their own rebuild
                        } else {
                            opts = resolvedStaticOptions(optionsDef)
                        }
                        let selections = currentSelections(writablePath: writablePath, dataContext: context.dataContext)
                        rebuildOptions(
                            container: container, options: opts,
                            selectedValues: selections, filterText: filterText,
                            isMutuallyExclusive: isMutuallyExclusive, isChips: isChips,
                            writablePath: writablePath, dataContext: context.dataContext
                        )
                    }
                wrapper.storeCancellable(cancellable)
            }

            // Initial render
            let initialOpts = resolvedStaticOptions(optionsDef)
            let initialSelections = currentSelections(writablePath: writablePath, dataContext: context.dataContext)
            rebuildOptions(
                container: optionsContainer, options: initialOpts,
                selectedValues: initialSelections, filterText: filterText,
                isMutuallyExclusive: isMutuallyExclusive, isChips: isChips,
                writablePath: writablePath, dataContext: context.dataContext
            )

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

    // MARK: - Helpers

    private static func resolvedStaticOptions(_ optionsDef: Any?) -> [JsonMap] {
        (optionsDef as? [JsonMap]) ?? []
    }

    private static func currentSelections(writablePath: String?, dataContext: DataContext) -> [String] {
        guard let path = writablePath else { return [] }
        let value = dataContext.getValue(pathString: path)
        if let arr = value as? [Any] { return arr.map { "\($0)" } }
        if let str = value as? String { return [str] }
        return []
    }

    private static func rebuildOptions(
        container: UIStackView,
        options: [JsonMap],
        selectedValues: [String],
        filterText: String,
        isMutuallyExclusive: Bool,
        isChips: Bool,
        writablePath: String?,
        dataContext: DataContext
    ) {
        container.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for option in options {
            let optionLabel = option["label"] as? String ?? ""
            let optionValue = option["value"] as? String ?? optionLabel

            if !filterText.isEmpty &&
               !optionLabel.lowercased().contains(filterText.lowercased()) {
                continue
            }

            let isSelected = selectedValues.contains(optionValue)

            if isChips {
                let chip = makeChipButton(
                    label: optionLabel, isSelected: isSelected,
                    onTap: {
                        toggleSelection(
                            value: optionValue, isSelected: !isSelected,
                            isMutuallyExclusive: isMutuallyExclusive,
                            writablePath: writablePath, dataContext: dataContext
                        )
                    }
                )
                container.addArrangedSubview(chip)
            } else if isMutuallyExclusive {
                let row = makeRadioRow(
                    label: optionLabel, isSelected: isSelected,
                    onTap: {
                        guard let path = writablePath else { return }
                        dataContext.update(pathString: path, value: [optionValue])
                    }
                )
                container.addArrangedSubview(row)
            } else {
                let row = makeCheckboxRow(
                    label: optionLabel, isSelected: isSelected,
                    onTap: {
                        toggleSelection(
                            value: optionValue, isSelected: !isSelected,
                            isMutuallyExclusive: false,
                            writablePath: writablePath, dataContext: dataContext
                        )
                    }
                )
                container.addArrangedSubview(row)
            }
        }
    }

    private static func toggleSelection(
        value: String,
        isSelected: Bool,
        isMutuallyExclusive: Bool,
        writablePath: String?,
        dataContext: DataContext
    ) {
        guard let path = writablePath else { return }
        if isMutuallyExclusive {
            dataContext.update(pathString: path, value: [value])
            return
        }
        var current = currentSelections(writablePath: path, dataContext: dataContext)
        if isSelected {
            if !current.contains(value) { current.append(value) }
        } else {
            current.removeAll { $0 == value }
        }
        dataContext.update(pathString: path, value: current)
    }

    // MARK: - UI Factories

    private static func makeChipButton(label: String, isSelected: Bool, onTap: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.layer.cornerRadius = 16
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)

        if isSelected {
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = .secondarySystemBackground
            button.setTitleColor(.label, for: .normal)
        }

        button.addAction(UIAction { _ in onTap() }, for: .touchUpInside)
        return button
    }

    private static func makeRadioRow(label: String, isSelected: Bool, onTap: @escaping () -> Void) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        let indicator = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        indicator.image = UIImage(
            systemName: isSelected ? "largecircle.fill.circle" : "circle",
            withConfiguration: config
        )
        indicator.tintColor = isSelected ? .systemBlue : .tertiaryLabel
        indicator.setContentHuggingPriority(.required, for: .horizontal)
        stack.addArrangedSubview(indicator)

        let textLabel = UILabel()
        textLabel.text = label
        textLabel.font = .systemFont(ofSize: 15)
        stack.addArrangedSubview(textLabel)

        let button = UIButton(type: .system)
        button.addAction(UIAction { _ in onTap() }, for: .touchUpInside)
        button.setTitle("", for: .normal)
        stack.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: stack.topAnchor),
            button.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: stack.bottomAnchor)
        ])

        return stack
    }

    private static func makeCheckboxRow(label: String, isSelected: Bool, onTap: @escaping () -> Void) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        let indicator = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        indicator.image = UIImage(
            systemName: isSelected ? "checkmark.square.fill" : "square",
            withConfiguration: config
        )
        indicator.tintColor = isSelected ? .systemBlue : .tertiaryLabel
        indicator.setContentHuggingPriority(.required, for: .horizontal)
        stack.addArrangedSubview(indicator)

        let textLabel = UILabel()
        textLabel.text = label
        textLabel.font = .systemFont(ofSize: 15)
        stack.addArrangedSubview(textLabel)

        let button = UIButton(type: .system)
        button.addAction(UIAction { _ in onTap() }, for: .touchUpInside)
        button.setTitle("", for: .normal)
        stack.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: stack.topAnchor),
            button.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: stack.bottomAnchor)
        ])

        return stack
    }
}
