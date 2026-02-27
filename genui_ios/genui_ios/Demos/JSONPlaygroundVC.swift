import UIKit
import A2UI

/// Allows free-form JSON input and renders the result live via the A2UI engine.
class JSONPlaygroundVC: UIViewController {

    private var controller: SurfaceController!
    private var surfaceView: SurfaceView?
    private let surfaceId = "playground"

    private lazy var jsonTextView: UITextView = {
        let tv = UITextView()
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.backgroundColor = .secondarySystemBackground
        tv.layer.cornerRadius = 8
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.keyboardDismissMode = .interactive
        tv.text = Self.sampleSimpleText
        return tv
    }()

    private lazy var errorLabel: UILabel = {
        let l = UILabel()
        l.textColor = .systemRed
        l.font = .systemFont(ofSize: 13)
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    private lazy var renderScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.backgroundColor = .systemBackground
        sv.layer.cornerRadius = 8
        sv.layer.borderWidth = 1.0 / UIScreen.main.scale
        sv.layer.borderColor = UIColor.separator.cgColor
        return sv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])

        setupLayout()
        renderJSON()
    }

    // MARK: - Layout

    private func setupLayout() {
        let renderButton = makeToolbarButton(title: "Render", systemImage: "play.fill", action: #selector(renderTapped))
        let clearButton = makeToolbarButton(title: "Clear", systemImage: "trash", action: #selector(clearTapped))
        let samplesButton = makeSamplesButton()

        let toolbar = UIStackView(arrangedSubviews: [renderButton, samplesButton, UIView(), clearButton])
        toolbar.axis = .horizontal
        toolbar.spacing = 12
        toolbar.alignment = .center

        let mainStack = UIStackView(arrangedSubviews: [jsonTextView, toolbar, errorLabel, renderScrollView])
        mainStack.axis = .vertical
        mainStack.spacing = 8

        view.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
            jsonTextView.heightAnchor.constraint(equalTo: mainStack.heightAnchor, multiplier: 0.45),
        ])
    }

    private func makeToolbarButton(title: String, systemImage: String, action: Selector) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = title
        cfg.image = UIImage(systemName: systemImage)
        cfg.imagePadding = 4
        cfg.cornerStyle = .medium
        cfg.buttonSize = .small
        let btn = UIButton(configuration: cfg)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func makeSamplesButton() -> UIButton {
        var cfg = UIButton.Configuration.tinted()
        cfg.title = "Samples"
        cfg.image = UIImage(systemName: "doc.text")
        cfg.imagePadding = 4
        cfg.cornerStyle = .medium
        cfg.buttonSize = .small
        let btn = UIButton(configuration: cfg)

        let items: [(String, String)] = [
            ("Simple Text", Self.sampleSimpleText),
            ("Form", Self.sampleForm),
            ("Card Layout", Self.sampleCardLayout),
            ("Data Binding", Self.sampleDataBinding),
            ("Tabs", Self.sampleTabs),
            ("v0.8 Email List", Self.sampleV08EmailList),
            ("v0.8 Profile Card", Self.sampleV08ProfileCard),
        ]
        btn.menu = UIMenu(children: items.map { name, json in
            UIAction(title: name) { [weak self] _ in
                self?.jsonTextView.text = json
                self?.renderJSON()
            }
        })
        btn.showsMenuAsPrimaryAction = true
        return btn
    }

    // MARK: - Actions

    @objc private func renderTapped() {
        renderJSON()
    }

    @objc private func clearTapped() {
        jsonTextView.text = ""
        errorLabel.isHidden = true
        clearSurface()
    }

    private func renderJSON() {
        view.endEditing(true)
        errorLabel.isHidden = true
        clearSurface()

        guard let text = jsonTextView.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        guard let data = text.data(using: .utf8) else {
            showError("Failed to encode text as UTF-8")
            return
        }

        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            showError("JSON parse error: \(error.localizedDescription)")
            return
        }

        let jsonArray: [JsonMap]
        if let arr = parsed as? [JsonMap] {
            jsonArray = arr
        } else if let single = parsed as? JsonMap {
            jsonArray = [single]
        } else {
            showError("Expected a JSON object or array of objects")
            return
        }

        var messages: [A2UIMessage] = []
        for (i, obj) in jsonArray.enumerated() {
            do {
                let msg = try A2UIMessage.fromJSON(obj)
                messages.append(msg)
            } catch {
                showError("Message[\(i)]: \(error.localizedDescription)")
                return
            }
        }

        for msg in messages {
            controller.handleMessage(msg)
        }

        let usedSurfaceId = messages.first?.surfaceId ?? surfaceId
        let sv = SurfaceView(surfaceContext: controller.contextFor(surfaceId: usedSurfaceId))
        self.surfaceView = sv
        renderScrollView.addSubview(sv)
        sv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: renderScrollView.contentLayoutGuide.topAnchor, constant: 12),
            sv.leadingAnchor.constraint(equalTo: renderScrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            sv.trailingAnchor.constraint(equalTo: renderScrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            sv.bottomAnchor.constraint(equalTo: renderScrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            sv.widthAnchor.constraint(equalTo: renderScrollView.frameLayoutGuide.widthAnchor, constant: -24),
        ])
    }

    private func clearSurface() {
        surfaceView?.removeFromSuperview()
        surfaceView = nil
        controller.dispose()
        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    // MARK: - Sample JSON Templates

    private static let sampleSimpleText = """
    [
      {
        "version": "v0.9",
        "createSurface": { "surfaceId": "playground", "catalogId": "com.google.genui.basic" }
      },
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "playground",
          "components": [
            { "id": "root", "component": "Column", "children": ["t1", "t2"] },
            { "id": "t1", "component": "Text", "text": "Hello, A2UI!", "variant": "h2" },
            { "id": "t2", "component": "Text", "text": "Edit this JSON and tap **Render** to see changes.", "variant": "body" }
          ]
        }
      }
    ]
    """

    private static let sampleForm = """
    [
      {
        "version": "v0.9",
        "createSurface": { "surfaceId": "playground", "catalogId": "com.google.genui.basic" }
      },
      {
        "version": "v0.9",
        "updateDataModel": { "surfaceId": "playground", "path": "/", "value": { "name": "", "agree": false } }
      },
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "playground",
          "components": [
            { "id": "root", "component": "Column", "children": ["tf", "cb", "btn"] },
            { "id": "tf", "component": "TextField", "value": { "path": "/name" }, "label": "Name", "placeholder": "Your name" },
            { "id": "cb", "component": "CheckBox", "value": { "path": "/agree" }, "label": "I agree" },
            { "id": "btn", "component": "Button", "child": "bt", "variant": "primary", "action": { "event": { "name": "submit" } } },
            { "id": "bt", "component": "Text", "text": "Submit" }
          ]
        }
      }
    ]
    """

    private static let sampleCardLayout = """
    [
      {
        "version": "v0.9",
        "createSurface": { "surfaceId": "playground", "catalogId": "com.google.genui.basic" }
      },
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "playground",
          "components": [
            { "id": "root", "component": "Column", "children": ["card1", "card2"] },
            { "id": "card1", "component": "Card", "child": "c1" },
            { "id": "c1", "component": "Column", "children": ["c1_row", "c1_desc"] },
            { "id": "c1_row", "component": "Row", "children": ["c1_icon", "c1_title"], "align": "center" },
            { "id": "c1_icon", "component": "Icon", "icon": "star", "size": 24, "color": "orange" },
            { "id": "c1_title", "component": "Text", "text": "Featured", "variant": "h4" },
            { "id": "c1_desc", "component": "Text", "text": "A card layout with an icon header.", "variant": "body" },
            { "id": "card2", "component": "Card", "child": "c2" },
            { "id": "c2", "component": "Column", "children": ["c2_title", "c2_btn"] },
            { "id": "c2_title", "component": "Text", "text": "Action Card", "variant": "h5" },
            { "id": "c2_btn", "component": "Button", "child": "c2_bt", "variant": "primary", "action": { "event": { "name": "tap" } } },
            { "id": "c2_bt", "component": "Text", "text": "Go" }
          ]
        }
      }
    ]
    """

    private static let sampleDataBinding = """
    [
      {
        "version": "v0.9",
        "createSurface": { "surfaceId": "playground", "catalogId": "com.google.genui.basic" }
      },
      {
        "version": "v0.9",
        "updateDataModel": { "surfaceId": "playground", "path": "/", "value": { "user": "World", "volume": 50 } }
      },
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "playground",
          "components": [
            { "id": "root", "component": "Column", "children": ["tf", "greeting", "div", "sl", "sv"] },
            { "id": "tf", "component": "TextField", "value": { "path": "/user" }, "label": "Name" },
            { "id": "greeting", "component": "Text", "text": { "path": "/user" }, "variant": "h3" },
            { "id": "div", "component": "Divider" },
            { "id": "sl", "component": "Slider", "value": { "path": "/volume" }, "min": 0, "max": 100, "label": "Volume" },
            { "id": "sv", "component": "Text", "text": { "path": "/volume" }, "variant": "caption" }
          ]
        }
      }
    ]
    """

    private static let sampleTabs = """
    [
      {
        "version": "v0.9",
        "createSurface": { "surfaceId": "playground", "catalogId": "com.google.genui.basic" }
      },
      {
        "version": "v0.9",
        "updateComponents": {
          "surfaceId": "playground",
          "components": [
            { "id": "root", "component": "Tabs", "tabs": [
                { "label": "Info", "content": "tab_info" },
                { "label": "Settings", "content": "tab_settings" }
              ]
            },
            { "id": "tab_info", "component": "Column", "children": ["info_t1", "info_t2"] },
            { "id": "info_t1", "component": "Text", "text": "Information Tab", "variant": "h4" },
            { "id": "info_t2", "component": "Text", "text": "This is the first tab content.", "variant": "body" },
            { "id": "tab_settings", "component": "Column", "children": ["set_t1", "set_cb"] },
            { "id": "set_t1", "component": "Text", "text": "Settings Tab", "variant": "h4" },
            { "id": "set_cb", "component": "CheckBox", "value": { "path": "/toggle" }, "label": "Enable feature" }
          ]
        }
      }
    ]
    """

    // MARK: - v0.8 Format Samples (no version field, old message names)

    private static let sampleV08EmailList = """
    [
      {
        "beginRendering": {
          "surfaceId": "playground",
          "root": "root",
          "styles": { "primaryColor": "#1976D2" }
        }
      },
      {
        "surfaceUpdate": {
          "surfaceId": "playground",
          "components": [
            { "id": "root", "component": { "Column": { "children": { "explicitList": ["title-text", "email-list-comp"] } } } },
            { "id": "title-text", "component": { "Text": { "text": { "literalString": "Recent Emails" }, "usageHint": "h2" } } },
            { "id": "email-list-comp", "component": { "Column": { "children": { "template": { "componentId": "email-card", "dataBinding": "/emails" } } } } },
            { "id": "email-card", "component": { "Card": { "child": "email-card-content" } } },
            { "id": "email-card-content", "component": { "Column": { "children": { "explicitList": ["email-subject", "email-from", "email-snippet"] } } } },
            { "id": "email-subject", "component": { "Text": { "text": { "path": "subject" }, "usageHint": "h4" } } },
            { "id": "email-from", "component": { "Text": { "text": { "path": "from" }, "usageHint": "caption" } } },
            { "id": "email-snippet", "component": { "Text": { "text": { "path": "snippet" }, "usageHint": "body" } } }
          ]
        }
      },
      {
        "dataModelUpdate": {
          "surfaceId": "playground",
          "path": "/",
          "contents": [
            { "key": "emails", "valueMap": [
              { "key": "email1", "valueMap": [
                { "key": "subject", "valueString": "Meeting Tomorrow" },
                { "key": "from", "valueString": "alice@example.com" },
                { "key": "snippet", "valueString": "Hi, just a reminder about our meeting..." }
              ]},
              { "key": "email2", "valueMap": [
                { "key": "subject", "valueString": "Project Update" },
                { "key": "from", "valueString": "bob@example.com" },
                { "key": "snippet", "valueString": "The latest build is ready for review..." }
              ]}
            ]}
          ]
        }
      }
    ]
    """

    private static let sampleV08ProfileCard = """
    [
      {
        "beginRendering": { "surfaceId": "playground", "root": "root" }
      },
      {
        "surfaceUpdate": {
          "surfaceId": "playground",
          "components": [
            { "id": "root", "component": { "Column": { "children": { "explicitList": ["profile_card"] } } } },
            { "id": "profile_card", "component": { "Card": { "child": "card_content" } } },
            { "id": "card_content", "component": { "Column": { "children": { "explicitList": ["name_text", "handle_text", "bio_text"] } } } },
            { "id": "name_text", "component": { "Text": { "text": { "literalString": "A2UI Fan" }, "usageHint": "h3" } } },
            { "id": "handle_text", "component": { "Text": { "text": { "literalString": "@a2ui_fan" }, "usageHint": "caption" } } },
            { "id": "bio_text", "component": { "Text": { "text": { "literalString": "Building beautiful apps from a single codebase." }, "usageHint": "body" } } }
          ]
        }
      }
    ]
    """
}
