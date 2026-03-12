import UIKit
import A2UI

/// A scrollable gallery showcasing all 18 A2UI components, grouped by category.
/// Each component card includes a live preview and a "View JSON" button.
class ComponentGalleryVC: UIViewController {

    private var controller: SurfaceController!

    private struct Section {
        let name: String
        let category: String
        let categoryColor: UIColor
        let surfaceId: String
        let components: [Component]
        let dataModel: JsonMap?
        let fixedHeight: CGFloat?

        init(name: String, category: String, categoryColor: UIColor, surfaceId: String,
             components: [Component], dataModel: JsonMap? = nil, fixedHeight: CGFloat? = nil) {
            self.name = name
            self.category = category
            self.categoryColor = categoryColor
            self.surfaceId = surfaceId
            self.components = components
            self.dataModel = dataModel
            self.fixedHeight = fixedHeight
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])

        let sections = Self.buildAllSections()

        for s in sections {
            controller.handleMessage(.createSurface(CreateSurfacePayload(
                surfaceId: s.surfaceId, catalogId: basicCatalogId
            )))
            if let dm = s.dataModel {
                controller.handleMessage(.updateDataModel(UpdateDataModelPayload(
                    surfaceId: s.surfaceId, path: .root, value: dm
                )))
            }
            controller.handleMessage(.updateComponents(UpdateComponentsPayload(
                surfaceId: s.surfaceId, components: s.components
            )))
        }

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        scrollView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        var lastCategory = ""
        for s in sections {
            if s.category != lastCategory {
                lastCategory = s.category
                stack.addArrangedSubview(makeCategoryHeader(s.category))
            }
            stack.addArrangedSubview(makeCard(s))
        }
    }

    // MARK: - UI Builders

    private func makeCategoryHeader(_ title: String) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        let wrapper = UIView()
        wrapper.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])
        return wrapper
    }

    private func makeCard(_ section: Section) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        card.clipsToBounds = true

        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 0
        card.addSubview(vStack)
        vStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        // Header with badge + name
        let headerContainer = UIView()
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerContainer.addSubview(headerStack)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            headerStack.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8),
        ])

        let badge = BadgeLabel()
        badge.text = section.category
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = .white
        badge.backgroundColor = section.categoryColor
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true
        badge.padding = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        headerStack.addArrangedSubview(badge)

        let nameLabel = UILabel()
        nameLabel.text = section.name
        nameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        headerStack.addArrangedSubview(nameLabel)

        vStack.addArrangedSubview(headerContainer)

        // Live preview
        let previewContainer = UIView()
        previewContainer.backgroundColor = .systemBackground
        let surfaceView = SurfaceView(surfaceContext: controller.contextFor(surfaceId: section.surfaceId))
        previewContainer.addSubview(surfaceView)
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 12),
            surfaceView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 16),
            surfaceView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),
            surfaceView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -12),
        ])
        if let h = section.fixedHeight {
            previewContainer.heightAnchor.constraint(equalToConstant: h).isActive = true
            previewContainer.clipsToBounds = true
        }
        vStack.addArrangedSubview(previewContainer)

        // Separator
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        vStack.addArrangedSubview(sep)

        // View JSON button
        var cfg = UIButton.Configuration.plain()
        cfg.title = "View JSON"
        cfg.image = UIImage(systemName: "chevron.left.forwardslash.chevron.right")
        cfg.imagePadding = 6
        cfg.baseForegroundColor = .secondaryLabel
        let btn = UIButton(configuration: cfg)
        btn.contentHorizontalAlignment = .leading
        btn.addAction(UIAction { [weak self] _ in
            self?.showJSON(section)
        }, for: .touchUpInside)
        vStack.addArrangedSubview(btn)

        return card
    }

    // MARK: - JSON Viewer

    private func showJSON(_ section: Section) {
        let vc = GalleryJSONViewerVC(sectionName: section.name, json: formatJSON(section))
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    private func formatJSON(_ section: Section) -> String {
        var msgs: [JsonMap] = []
        msgs.append([
            "version": "v0.9",
            "createSurface": [
                "surfaceId": section.surfaceId,
                "catalogId": "com.google.genui.basic"
            ] as JsonMap
        ])
        if let dm = section.dataModel {
            msgs.append([
                "version": "v0.9",
                "updateDataModel": [
                    "surfaceId": section.surfaceId,
                    "path": "/",
                    "value": dm
                ] as JsonMap
            ])
        }
        msgs.append([
            "version": "v0.9",
            "updateComponents": [
                "surfaceId": section.surfaceId,
                "components": section.components.map { $0.toJSON() }
            ] as JsonMap
        ])
        guard let data = try? JSONSerialization.data(withJSONObject: msgs, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    // MARK: - All Section Definitions

    private static let display = UIColor.systemBlue
    private static let layout  = UIColor.systemGreen
    private static let input   = UIColor.systemOrange
    private static let action  = UIColor.systemPurple

    private static func buildAllSections() -> [Section] {
        [
            textSection(), iconSection(), imageSection(),
            columnSection(), rowSection(), cardSection(), dividerSection(), listSection(), tabsSection(),
            textFieldSection(), checkBoxSection(), sliderSection(), choicePickerSection(), dateTimeInputSection(),
            buttonSection(), modalSection(),
            photoInputSection(),
        ]
    }

    // MARK: Display

    private static func textSection() -> Section {
        Section(name: "Text", category: "Display", categoryColor: display, surfaceId: "g-text", components: [
            Component(id: "root", type: "Column", properties: ["children": ["t1", "t2", "t3", "t4", "t5"]]),
            Component(id: "t1", type: "Text", properties: ["text": "Heading 2", "variant": "h2"]),
            Component(id: "t2", type: "Text", properties: ["text": "Heading 4", "variant": "h4"]),
            Component(id: "t3", type: "Text", properties: ["text": "Body text with regular style.", "variant": "body"]),
            Component(id: "t4", type: "Text", properties: ["text": "Caption (small & secondary)", "variant": "caption"]),
            Component(id: "t5", type: "Text", properties: [
                "text": "Supports **bold**, *italic*, and [links](https://example.com)", "variant": "body"
            ]),
        ])
    }

    private static func iconSection() -> Section {
        Section(name: "Icon", category: "Display", categoryColor: display, surfaceId: "g-icon", components: [
            Component(id: "root", type: "Row", properties: [
                "children": ["i1", "i2", "i3", "i4", "i5"], "align": "center"
            ]),
            Component(id: "i1", type: "Icon", properties: ["icon": "star", "size": 32, "color": "orange"]),
            Component(id: "i2", type: "Icon", properties: ["icon": "favorite", "size": 32, "color": "red"]),
            Component(id: "i3", type: "Icon", properties: ["icon": "search", "size": 32, "color": "blue"]),
            Component(id: "i4", type: "Icon", properties: ["icon": "home", "size": 32, "color": "green"]),
            Component(id: "i5", type: "Icon", properties: ["icon": "settings", "size": 32, "color": "gray"]),
        ])
    }

    private static func imageSection() -> Section {
        Section(name: "Image", category: "Display", categoryColor: display, surfaceId: "g-image", components: [
            Component(id: "root", type: "Column", properties: ["children": ["img", "cap"]]),
            Component(id: "img", type: "Image", properties: [
                "url": "https://picsum.photos/seed/a2ui/400/200", "fit": "cover"
            ]),
            Component(id: "cap", type: "Text", properties: [
                "text": "Image loaded from URL (fit: cover)", "variant": "caption"
            ]),
        ])
    }

    // MARK: Layout

    private static func columnSection() -> Section {
        Section(name: "Column", category: "Layout", categoryColor: layout, surfaceId: "g-column", components: [
            Component(id: "root", type: "Column", properties: [
                "children": ["c1", "c2", "c3"], "align": "stretch"
            ]),
            Component(id: "c1", type: "Card", properties: ["child": "c1t"]),
            Component(id: "c1t", type: "Text", properties: ["text": "First Item", "variant": "body"]),
            Component(id: "c2", type: "Card", properties: ["child": "c2t"]),
            Component(id: "c2t", type: "Text", properties: ["text": "Second Item", "variant": "body"]),
            Component(id: "c3", type: "Card", properties: ["child": "c3t"]),
            Component(id: "c3t", type: "Text", properties: ["text": "Third Item", "variant": "body"]),
        ])
    }

    private static func rowSection() -> Section {
        Section(name: "Row", category: "Layout", categoryColor: layout, surfaceId: "g-row", components: [
            Component(id: "root", type: "Row", properties: [
                "children": ["r1", "r2", "r3"], "align": "center", "justify": "spaceEvenly"
            ]),
            Component(id: "r1", type: "Icon", properties: ["icon": "star", "size": 28, "color": "orange"]),
            Component(id: "r2", type: "Text", properties: ["text": "Centered Row", "variant": "h5"]),
            Component(id: "r3", type: "Icon", properties: ["icon": "favorite", "size": 28, "color": "red"]),
        ])
    }

    private static func cardSection() -> Section {
        Section(name: "Card", category: "Layout", categoryColor: layout, surfaceId: "g-card", components: [
            Component(id: "root", type: "Card", properties: ["child": "inner"]),
            Component(id: "inner", type: "Column", properties: ["children": ["ct", "cb"]]),
            Component(id: "ct", type: "Text", properties: ["text": "Card Title", "variant": "h4"]),
            Component(id: "cb", type: "Text", properties: [
                "text": "Cards wrap content with a subtle shadow and rounded corners.", "variant": "body"
            ]),
        ])
    }

    private static func dividerSection() -> Section {
        Section(name: "Divider", category: "Layout", categoryColor: layout, surfaceId: "g-divider", components: [
            Component(id: "root", type: "Column", properties: ["children": ["d1", "div", "d2"]]),
            Component(id: "d1", type: "Text", properties: ["text": "Above the divider", "variant": "body"]),
            Component(id: "div", type: "Divider", properties: [:]),
            Component(id: "d2", type: "Text", properties: ["text": "Below the divider", "variant": "body"]),
        ])
    }

    private static func listSection() -> Section {
        Section(name: "List", category: "Layout", categoryColor: layout, surfaceId: "g-list", components: [
            Component(id: "root", type: "List", properties: [
                "children": ["l1", "l2", "l3", "l4"], "direction": "vertical"
            ]),
            Component(id: "l1", type: "Card", properties: ["child": "l1t"]),
            Component(id: "l1t", type: "Text", properties: ["text": "Scrollable Item 1", "variant": "body"]),
            Component(id: "l2", type: "Card", properties: ["child": "l2t"]),
            Component(id: "l2t", type: "Text", properties: ["text": "Scrollable Item 2", "variant": "body"]),
            Component(id: "l3", type: "Card", properties: ["child": "l3t"]),
            Component(id: "l3t", type: "Text", properties: ["text": "Scrollable Item 3", "variant": "body"]),
            Component(id: "l4", type: "Card", properties: ["child": "l4t"]),
            Component(id: "l4t", type: "Text", properties: ["text": "Scrollable Item 4", "variant": "body"]),
        ], fixedHeight: 200)
    }

    private static func tabsSection() -> Section {
        Section(name: "Tabs", category: "Layout", categoryColor: layout, surfaceId: "g-tabs", components: [
            Component(id: "root", type: "Tabs", properties: [
                "tabs": [
                    ["label": "Tab A", "content": "ta"] as JsonMap,
                    ["label": "Tab B", "content": "tb"] as JsonMap,
                ] as [JsonMap]
            ]),
            Component(id: "ta", type: "Text", properties: ["text": "Content of Tab A", "variant": "body"]),
            Component(id: "tb", type: "Text", properties: ["text": "Content of Tab B", "variant": "body"]),
        ])
    }

    // MARK: Input

    private static func textFieldSection() -> Section {
        Section(name: "TextField", category: "Input", categoryColor: input, surfaceId: "g-textfield", components: [
            Component(id: "root", type: "TextField", properties: [
                "value": ["path": "/name"] as JsonMap,
                "label": "Your Name",
                "placeholder": "Enter text here"
            ]),
        ], dataModel: ["name": ""])
    }

    private static func checkBoxSection() -> Section {
        Section(name: "CheckBox", category: "Input", categoryColor: input, surfaceId: "g-checkbox", components: [
            Component(id: "root", type: "CheckBox", properties: [
                "value": ["path": "/agree"] as JsonMap,
                "label": "I agree to the terms and conditions"
            ]),
        ], dataModel: ["agree": false])
    }

    private static func sliderSection() -> Section {
        Section(name: "Slider", category: "Input", categoryColor: input, surfaceId: "g-slider", components: [
            Component(id: "root", type: "Column", properties: ["children": ["sl", "sv"]]),
            Component(id: "sl", type: "Slider", properties: [
                "value": ["path": "/volume"] as JsonMap,
                "min": 0, "max": 100, "label": "Volume"
            ]),
            Component(id: "sv", type: "Text", properties: [
                "text": ["path": "/volume"] as JsonMap, "variant": "caption"
            ]),
        ], dataModel: ["volume": 50])
    }

    private static func choicePickerSection() -> Section {
        Section(name: "ChoicePicker", category: "Input", categoryColor: input, surfaceId: "g-choice", components: [
            Component(id: "root", type: "ChoicePicker", properties: [
                "value": ["path": "/pick"] as JsonMap,
                "label": "Favorite Framework",
                "variant": "mutuallyExclusive",
                "options": [
                    ["label": "UIKit", "value": "uikit"] as JsonMap,
                    ["label": "SwiftUI", "value": "swiftui"] as JsonMap,
                    ["label": "Flutter", "value": "flutter"] as JsonMap,
                ] as [JsonMap]
            ]),
        ], dataModel: ["pick": "uikit"])
    }

    private static func dateTimeInputSection() -> Section {
        Section(name: "DateTimeInput", category: "Input", categoryColor: input, surfaceId: "g-datetime", components: [
            Component(id: "root", type: "DateTimeInput", properties: [
                "value": ["path": "/date"] as JsonMap,
                "label": "Select Date",
                "variant": "date"
            ]),
        ], dataModel: ["date": ""])
    }

    // MARK: Action

    private static func buttonSection() -> Section {
        Section(name: "Button", category: "Action", categoryColor: action, surfaceId: "g-button", components: [
            Component(id: "root", type: "Column", properties: ["children": ["b1", "b2", "b3"]]),
            Component(id: "b1", type: "Button", properties: [
                "child": "b1t", "variant": "primary",
                "action": ["event": ["name": "btn_tap"]] as JsonMap
            ]),
            Component(id: "b1t", type: "Text", properties: ["text": "Primary"]),
            Component(id: "b2", type: "Button", properties: [
                "child": "b2t", "variant": "borderless",
                "action": ["event": ["name": "btn_tap"]] as JsonMap
            ]),
            Component(id: "b2t", type: "Text", properties: ["text": "Borderless"]),
            Component(id: "b3", type: "Button", properties: [
                "child": "b3t",
                "action": ["event": ["name": "btn_tap"]] as JsonMap
            ]),
            Component(id: "b3t", type: "Text", properties: ["text": "Default"]),
        ])
    }

    private static func modalSection() -> Section {
        Section(name: "Modal", category: "Action", categoryColor: action, surfaceId: "g-modal", components: [
            Component(id: "root", type: "Modal", properties: ["trigger": "m_trig", "content": "m_body"]),
            Component(id: "m_trig", type: "Button", properties: ["child": "m_trig_t", "variant": "primary"]),
            Component(id: "m_trig_t", type: "Text", properties: ["text": "Open Modal"]),
            Component(id: "m_body", type: "Column", properties: ["children": ["m_h", "m_p"]]),
            Component(id: "m_h", type: "Text", properties: ["text": "Modal Content", "variant": "h3"]),
            Component(id: "m_p", type: "Text", properties: [
                "text": "This content is displayed in a bottom sheet overlay.", "variant": "body"
            ]),
        ])
    }

    // MARK: Media

    private static func photoInputSection() -> Section {
        Section(name: "PhotoInput", category: "Media", categoryColor: UIColor.systemTeal, surfaceId: "g-photo", components: [
            Component(id: "root", type: "PhotoInput", properties: [
                "value": ["path": "/photoUrl"] as JsonMap,
                "hasValue": ["path": "/hasPhoto"] as JsonMap,
                "placeholder": "Snap a pic"
            ]),
        ], dataModel: ["photoUrl": "", "hasPhoto": false])
    }
}

// MARK: - JSON Viewer

private class GalleryJSONViewerVC: UIViewController {
    private let sectionName: String
    private let json: String

    init(sectionName: String, json: String) {
        self.sectionName = sectionName
        self.json = json
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = sectionName
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain, target: self, action: #selector(copyJSON)
        )

        let textView = UITextView()
        textView.text = json
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    @objc private func copyJSON() {
        UIPasteboard.general.string = json
        let alert = UIAlertController(title: nil, message: "Copied to clipboard", preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { alert.dismiss(animated: true) }
    }
}

// MARK: - Badge Label

private class BadgeLabel: UILabel {
    var padding = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + padding.left + padding.right,
            height: size.height + padding.top + padding.bottom
        )
    }
}
