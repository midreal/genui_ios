import UIKit
import Combine

/// A date/time picker with data binding.
///
/// Parameters:
/// - `value`: Data binding definition for the date string (ISO 8601).
///   Also accepts legacy `binding` (string path).
/// - `variant`: `"date"` (default), `"time"`, or `"datetime"`.
///   Also accepts legacy `mode` with values `"dateAndTime"`.
/// - `label`: Optional label text. Supports `stringReference` (data binding).
/// - `min`: Minimum date string (YYYY-MM-DD).
/// - `max`: Maximum date string (YYYY-MM-DD).
/// - `enableDate` / `enableTime`: Legacy boolean toggles.
/// - `checks`: Array of `{condition, message}` for validation.
enum DateTimeInputComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "DateTimeInput", isImplicitlyFlexible: true) { context in
            let wrapper = BindableView()
            let valueDef = BoundValueHelpers.readValueDef(from: context.data)
            let writablePath = BoundValueHelpers.extractWritablePath(valueDef)
            let labelDef = context.data["label"]
            let checks = (context.data["checks"] as? [Any])?.compactMap { $0 as? JsonMap }

            // Resolve variant: prefer "variant", fallback to "mode"
            let variant = resolveVariant(from: context.data)

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 6
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

            let picker = UIDatePicker()
            picker.preferredDatePickerStyle = .compact
            switch variant {
            case "time": picker.datePickerMode = .time
            case "datetime": picker.datePickerMode = .dateAndTime
            default: picker.datePickerMode = .date
            }

            // min/max date constraints
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            if let minStr = context.data["min"] as? String, let minDate = dateOnlyFormatter.date(from: minStr) {
                picker.minimumDate = minDate
            }
            if let maxStr = context.data["max"] as? String, let maxDate = dateOnlyFormatter.date(from: maxStr) {
                picker.maximumDate = maxDate
            }

            stack.addArrangedSubview(picker)

            let errorLabel = UILabel()
            errorLabel.font = .systemFont(ofSize: 12)
            errorLabel.textColor = .systemRed
            errorLabel.numberOfLines = 0
            errorLabel.isHidden = true
            stack.addArrangedSubview(errorLabel)

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let valueDef = valueDef {
                var isUpdatingFromModel = false

                let cancellable = BoundValueHelpers.resolveString(valueDef, context: context.dataContext)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak picker] value in
                        guard let picker = picker else { return }
                        isUpdatingFromModel = true
                        if let dateStr = value, let date = isoFormatter.date(from: dateStr) {
                            picker.date = date
                        } else if let dateStr = value, let date = dateOnlyFormatter.date(from: dateStr) {
                            picker.date = date
                        }
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                if let path = writablePath {
                    let dataCtx = context.dataContext
                    picker.addAction(UIAction { [weak picker] _ in
                        guard !isUpdatingFromModel, let picker = picker else { return }
                        let outputStr: String
                        switch variant {
                        case "date":
                            outputStr = dateOnlyFormatter.string(from: picker.date)
                        case "time":
                            let tf = DateFormatter()
                            tf.dateFormat = "HH:mm:00"
                            outputStr = tf.string(from: picker.date)
                        default:
                            outputStr = isoFormatter.string(from: picker.date)
                        }
                        dataCtx.update(pathString: path, value: outputStr)
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

    /// Resolves the picker variant from data, supporting both `variant`
    /// (new) and `mode` (legacy) fields, plus `enableDate`/`enableTime` booleans.
    private static func resolveVariant(from data: JsonMap) -> String {
        if let v = data["variant"] as? String { return v }

        if let mode = data["mode"] as? String {
            if mode == "dateAndTime" { return "datetime" }
            return mode
        }

        let enableDate = data["enableDate"] as? Bool ?? true
        let enableTime = data["enableTime"] as? Bool ?? false
        if enableDate && enableTime { return "datetime" }
        if enableTime { return "time" }
        return "date"
    }
}
