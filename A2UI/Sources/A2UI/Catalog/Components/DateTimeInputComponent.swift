import UIKit
import Combine

/// A date/time picker with data binding.
///
/// Parameters:
/// - `binding`: Data path for the date string (ISO 8601).
/// - `mode`: "date", "time", or "dateAndTime" (default "date").
/// - `label`: Optional label text.
/// - `checks`: Array of `{condition, message}` for validation.
enum DateTimeInputComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "DateTimeInput", isImplicitlyFlexible: true) { context in
            let wrapper = BindableView()
            let bindingPath = context.data["binding"] as? String
            let mode = context.data["mode"] as? String ?? "date"
            let labelText = context.data["label"] as? String
            let checks = (context.data["checks"] as? [Any])?.compactMap { $0 as? JsonMap }

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 6
            wrapper.embed(stack)

            if let text = labelText {
                let label = UILabel()
                label.text = text
                label.font = .systemFont(ofSize: 13, weight: .medium)
                label.textColor = .secondaryLabel
                stack.addArrangedSubview(label)
            }

            let picker = UIDatePicker()
            picker.preferredDatePickerStyle = .compact
            switch mode {
            case "time": picker.datePickerMode = .time
            case "dateAndTime": picker.datePickerMode = .dateAndTime
            default: picker.datePickerMode = .date
            }
            stack.addArrangedSubview(picker)

            let errorLabel = UILabel()
            errorLabel.font = .systemFont(ofSize: 12)
            errorLabel.textColor = .systemRed
            errorLabel.numberOfLines = 0
            errorLabel.isHidden = true
            stack.addArrangedSubview(errorLabel)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let path = bindingPath {
                var isUpdatingFromModel = false

                let cancellable = context.dataContext.subscribe(pathString: path)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak picker] value in
                        guard let picker = picker else { return }
                        isUpdatingFromModel = true
                        if let dateStr = value as? String, let date = formatter.date(from: dateStr) {
                            picker.date = date
                        }
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                let dataCtx = context.dataContext
                picker.addAction(UIAction { [weak picker] _ in
                    guard !isUpdatingFromModel, let picker = picker else { return }
                    dataCtx.update(pathString: path, value: formatter.string(from: picker.date))
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
