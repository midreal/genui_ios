import UIKit
import Combine

/// A segmented control for single-choice selection with data binding.
///
/// Parameters:
/// - `binding`: Data path for the selected value.
/// - `options`: Array of `{"label": "...", "value": "..."}` objects.
enum ChoicePickerComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "ChoicePicker") { context in
            let wrapper = BindableView()
            let bindingPath = context.data["binding"] as? String
            let options = context.data["options"] as? [JsonMap] ?? []
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

            let labels = options.map { $0["label"] as? String ?? "" }
            let values = options.map { $0["value"] ?? $0["label"] ?? "" }
            let segmented = UISegmentedControl(items: labels)
            stack.addArrangedSubview(segmented)

            if let path = bindingPath {
                var isUpdatingFromModel = false

                let cancellable = context.dataContext.subscribe(pathString: path)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak segmented] value in
                        guard let segmented = segmented else { return }
                        isUpdatingFromModel = true
                        if let strVal = value as? String,
                           let idx = values.firstIndex(where: { "\($0)" == strVal }) {
                            segmented.selectedSegmentIndex = idx
                        } else if let numVal = value as? Int, numVal < values.count {
                            segmented.selectedSegmentIndex = numVal
                        } else {
                            segmented.selectedSegmentIndex = UISegmentedControl.noSegment
                        }
                        isUpdatingFromModel = false
                    }
                wrapper.storeCancellable(cancellable)

                let dataCtx = context.dataContext
                segmented.addAction(UIAction { [weak segmented] _ in
                    guard !isUpdatingFromModel, let segmented = segmented else { return }
                    let idx = segmented.selectedSegmentIndex
                    guard idx >= 0, idx < values.count else { return }
                    dataCtx.update(pathString: path, value: values[idx])
                }, for: .valueChanged)
            }

            return wrapper
        }
    }
}
