import UIKit
import Combine

/// A date/time picker with data binding.
///
/// Parameters:
/// - `binding`: Data path for the date string (ISO 8601).
/// - `mode`: "date", "time", or "dateAndTime" (default "date").
/// - `label`: Optional label text.
enum DateTimeInputComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "DateTimeInput") { context in
            let wrapper = BindableView()
            let bindingPath = context.data["binding"] as? String
            let mode = context.data["mode"] as? String ?? "date"
            let labelText = context.data["label"] as? String

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

            return wrapper
        }
    }
}
