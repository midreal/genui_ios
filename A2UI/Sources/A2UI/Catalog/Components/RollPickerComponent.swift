import UIKit
import Combine

/// A slot-machine style picker with 1-3 columns.
///
/// Parameters:
/// - `columns`: Array of `{title, items}` (max 3 columns).
/// - `selection`: String array reference for display values.
/// - `hasCustomSelection`: Optional boolean reference.
enum RollPickerComponent {

    private static let maxColumnCount = 3
    private static let rollPickerHeight: CGFloat = 122
    private static let wheelItemHeight: CGFloat = 36
    private static let frameBorderWidth: CGFloat = 2
    private static let frameBorderColor = UIColor(red: 0xFF/255, green: 0x59/255, blue: 0x6C/255, alpha: 1)
    private static let frameEdgeGradientColor = UIColor(red: 0xFF/255, green: 0xEA/255, blue: 0xE3/255, alpha: 1)
    private static let sideDecorWidth: CGFloat = 6
    private static let sideDecorHeight: CGFloat = 44
    private static let sideDecorRadius: CGFloat = 8
    private static let centerTextColor = MacaronColors.label
    private static let neighborTextColor = MacaronColors.label.withAlphaComponent(0.1)
    private static let separatorWidth: CGFloat = 2

    static func register() -> CatalogItem {
        CatalogItem(name: "RollPicker") { context in
            let rawColumns = context.data["columns"] as? [JsonMap] ?? []
            let columns = parseColumns(rawColumns)
            guard !columns.isEmpty else { return UIView() }

            let selectionDef = context.data["selection"] as? JsonMap ?? [:]
            let selectionPath = selectionDef["path"] as? String
            let hasCustomSelectionPath = (context.data["hasCustomSelection"] as? JsonMap)?["path"] as? String

            let wrapper = BindableView()
            let pickerView = RollPickerView(
                columns: columns,
                dataContext: context.dataContext,
                selectionPath: selectionPath,
                hasCustomSelectionPath: hasCustomSelectionPath
            )
            pickerView.translatesAutoresizingMaskIntoConstraints = false
            wrapper.embed(pickerView)
            pickerView.heightAnchor.constraint(equalToConstant: rollPickerHeight).isActive = true

            // Subscribe to selection changes from data model
            let cancellable = context.dataContext.resolve(selectionDef)
                .receive(on: DispatchQueue.main)
                .sink { [weak pickerView] value in
                    guard let pickerView = pickerView else { return }
                    let rawSelection = value as? [Any] ?? []
                    pickerView.updateFromModel(rawSelection)
                }
            wrapper.storeCancellable(cancellable)

            return wrapper
        }
    }

    /// RollPickerCard: A fixed-layout Macaron card that embeds RollPicker
    /// and a submit button.
    static func registerCard() -> CatalogItem {
        CatalogItem(name: "RollPickerCard") { context in
            let rawColumns = context.data["columns"] as? [JsonMap] ?? []
            let columns = parseColumns(rawColumns)
            guard !columns.isEmpty else { return UIView() }

            let selectionDef = context.data["selection"] as? JsonMap ?? [:]
            let selectionPath = selectionDef["path"] as? String
            let hasCustomSelectionPath = (context.data["hasCustomSelection"] as? JsonMap)?["path"] as? String
            let action = context.data["action"] as? JsonMap ?? [:]
            let actionName = action["name"] as? String ?? ""

            let wrapper = BindableView()

            let cardView = UIView()
            cardView.backgroundColor = UIColor(red: 0xFF/255, green: 0xD1/255, blue: 0xC3/255, alpha: 1)
            cardView.layer.cornerRadius = 16
            cardView.layer.borderWidth = 0.5
            cardView.layer.borderColor = MacaronColors.cardBorder.cgColor
            cardView.clipsToBounds = true

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

            // Title
            let titleLabel = UILabel()
            titleLabel.text = "Ready to spin..."
            titleLabel.font = LabelComponent.resolveFont(variant: "title")
            titleLabel.textColor = MacaronColors.label

            let subtitleLabel = UILabel()
            subtitleLabel.text = "Or swipe to select"
            subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
            subtitleLabel.textColor = MacaronColors.secondary

            mainStack.addArrangedSubview(titleLabel)
            mainStack.addArrangedSubview(subtitleLabel)

            // Picker
            let pickerView = RollPickerView(
                columns: columns,
                dataContext: context.dataContext,
                selectionPath: selectionPath,
                hasCustomSelectionPath: hasCustomSelectionPath
            )
            pickerView.translatesAutoresizingMaskIntoConstraints = false
            pickerView.heightAnchor.constraint(equalToConstant: rollPickerHeight).isActive = true
            mainStack.addArrangedSubview(pickerView)

            // Button
            let button = GradientButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
            button.setTitle("🎲 Spin", for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            button.setTitleColor(MacaronColors.primaryButtonLight, for: .normal)
            mainStack.addArrangedSubview(button)

            // Update button text based on custom selection
            pickerView.onSelectionChanged = { [weak button] hasCustom in
                button?.setTitle(hasCustom ? "Get picks" : "🎲 Spin", for: .normal)
            }

            let dispatch = context.dispatchEvent
            let componentId = context.id
            button.addAction(UIAction { [weak pickerView] _ in
                guard let pickerView = pickerView else { return }
                let snapshot = pickerView.currentSnapshot()
                var resolvedContext: JsonMap = [:]
                resolvedContext["selectedValues"] = snapshot.selectedValues
                resolvedContext["selectedIndexes"] = snapshot.selectedIndexes
                resolvedContext["hasCustomSelection"] = snapshot.hasCustomSelection

                let event = UiEvent(data: [
                    "name": actionName,
                    "sourceComponentId": componentId,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "context": resolvedContext,
                ])
                dispatch(event)
            }, for: .touchUpInside)

            wrapper.embed(cardView)

            let cancellable = context.dataContext.resolve(selectionDef)
                .receive(on: DispatchQueue.main)
                .sink { [weak pickerView] value in
                    guard let pickerView = pickerView else { return }
                    let rawSelection = value as? [Any] ?? []
                    pickerView.updateFromModel(rawSelection)
                }
            wrapper.storeCancellable(cancellable)

            return wrapper
        }
    }

    // MARK: - Helpers

    struct RollPickerColumn {
        let title: String
        let items: [String]
        var displayValues: [String] { [title] + items }
    }

    struct SelectionSnapshot {
        let selectedValues: [String]
        let selectedIndexes: [Int]
        let hasCustomSelection: Bool
    }

    static func parseColumns(_ rawColumns: [JsonMap]) -> [RollPickerColumn] {
        var result: [RollPickerColumn] = []
        for raw in rawColumns {
            guard let title = raw["title"] as? String,
                  let items = raw["items"] as? [String] else { continue }
            result.append(RollPickerColumn(title: title, items: items))
            if result.count >= maxColumnCount { break }
        }
        return result
    }

    static func resolveDisplayIndexes(rawSelection: [Any], columns: [RollPickerColumn]) -> [Int] {
        var result = Array(repeating: 0, count: columns.count)
        for i in 0..<columns.count {
            guard i < rawSelection.count, let current = rawSelection[i] as? String else { continue }
            if let index = columns[i].displayValues.firstIndex(of: current) {
                result[i] = index
            }
        }
        return result
    }

    static func snapshotFromDisplayIndexes(columns: [RollPickerColumn], displayIndexes: [Int]) -> SelectionSnapshot {
        var selectedValues: [String] = []
        var selectedIndexes: [Int] = []

        for i in 0..<columns.count {
            let displayValues = columns[i].displayValues
            let safeIndex = min(max(displayIndexes[i], 0), displayValues.count - 1)
            selectedValues.append(displayValues[safeIndex])
            selectedIndexes.append(safeIndex - 1)
        }

        let hasCustomSelection = selectedIndexes.contains { $0 >= 0 }
        return SelectionSnapshot(
            selectedValues: selectedValues,
            selectedIndexes: selectedIndexes,
            hasCustomSelection: hasCustomSelection
        )
    }
}

// MARK: - Roll Picker View

private final class RollPickerView: UIView, UIPickerViewDataSource, UIPickerViewDelegate {
    let columns: [RollPickerComponent.RollPickerColumn]
    let dataContext: DataContext
    let selectionPath: String?
    let hasCustomSelectionPath: String?
    var onSelectionChanged: ((Bool) -> Void)?

    private let picker = UIPickerView()
    private var displayIndexes: [Int]
    private var isUpdatingFromModel = false

    init(columns: [RollPickerComponent.RollPickerColumn],
         dataContext: DataContext,
         selectionPath: String?,
         hasCustomSelectionPath: String?) {
        self.columns = columns
        self.dataContext = dataContext
        self.selectionPath = selectionPath
        self.hasCustomSelectionPath = hasCustomSelectionPath
        self.displayIndexes = Array(repeating: 0, count: columns.count)
        super.init(frame: .zero)

        backgroundColor = .white
        layer.cornerRadius = 12
        layer.borderWidth = 2
        layer.borderColor = UIColor(red: 0xFF/255, green: 0x59/255, blue: 0x6C/255, alpha: 1).cgColor
        clipsToBounds = true

        picker.dataSource = self
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: topAnchor),
            picker.leadingAnchor.constraint(equalTo: leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: trailingAnchor),
            picker.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Add side decorations
        let leftDecor = UIView()
        leftDecor.backgroundColor = UIColor(red: 0xFF/255, green: 0x59/255, blue: 0x6C/255, alpha: 1)
        leftDecor.layer.cornerRadius = 8
        leftDecor.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        leftDecor.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftDecor)
        NSLayoutConstraint.activate([
            leftDecor.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -6),
            leftDecor.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftDecor.widthAnchor.constraint(equalToConstant: 6),
            leftDecor.heightAnchor.constraint(equalToConstant: 44),
        ])

        let rightDecor = UIView()
        rightDecor.backgroundColor = UIColor(red: 0xFF/255, green: 0x59/255, blue: 0x6C/255, alpha: 1)
        rightDecor.layer.cornerRadius = 8
        rightDecor.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        rightDecor.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightDecor)
        NSLayoutConstraint.activate([
            rightDecor.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 6),
            rightDecor.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightDecor.widthAnchor.constraint(equalToConstant: 6),
            rightDecor.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func updateFromModel(_ rawSelection: [Any]) {
        let newIndexes = RollPickerComponent.resolveDisplayIndexes(rawSelection: rawSelection, columns: columns)
        guard newIndexes != displayIndexes else { return }
        displayIndexes = newIndexes
        isUpdatingFromModel = true
        for i in 0..<columns.count {
            picker.selectRow(displayIndexes[i], inComponent: i, animated: false)
        }
        isUpdatingFromModel = false
    }

    func currentSnapshot() -> RollPickerComponent.SelectionSnapshot {
        RollPickerComponent.snapshotFromDisplayIndexes(columns: columns, displayIndexes: displayIndexes)
    }

    // MARK: UIPickerViewDataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        columns.count
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        columns[component].displayValues.count
    }

    // MARK: UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        columns[component].displayValues[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard !isUpdatingFromModel else { return }
        displayIndexes[component] = row
        commitSelection()
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? UILabel()
        label.text = columns[component].displayValues[row]
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .semibold)

        let selectedRow = pickerView.selectedRow(inComponent: component)
        label.textColor = row == selectedRow
            ? MacaronColors.label
            : MacaronColors.label.withAlphaComponent(0.1)

        return label
    }

    private func commitSelection() {
        let snapshot = currentSnapshot()

        if let path = selectionPath, !path.isEmpty {
            dataContext.update(pathString: path, value: snapshot.selectedValues)
        }
        if let path = hasCustomSelectionPath, !path.isEmpty {
            dataContext.update(pathString: path, value: snapshot.hasCustomSelection)
        }

        onSelectionChanged?(snapshot.hasCustomSelection)
    }
}

// MARK: - Gradient Button

private final class GradientButton: UIButton {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [
            MacaronColors.gradientStart.cgColor,
            MacaronColors.gradientMid.cgColor,
            MacaronColors.gradientEnd.cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 1000
        layer.insertSublayer(gradientLayer, at: 0)
        layer.cornerRadius = 1000
        clipsToBounds = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = bounds.height / 2
    }
}
