import UIKit
import A2UI

/// Demo 3: Parses A2UI JSON strings through the full pipeline:
/// JSON → A2UIMessage → SurfaceController → SurfaceView.
class JSONParsingDemoVC: UIViewController {

    private var controller: SurfaceController!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])

        // Simulate raw A2UI JSON messages (as would arrive from the AI)
        let createJSON: JsonMap = [
            "version": "v0.9",
            "createSurface": [
                "surfaceId": "json-demo",
                "catalogId": basicCatalogId
            ] as JsonMap
        ]

        let updateJSON: JsonMap = [
            "version": "v0.9",
            "updateComponents": [
                "surfaceId": "json-demo",
                "components": [
                    ["id": "root", "component": "Column", "children": ["t1", "t2", "card", "picker"]],
                    ["id": "t1", "component": "Text", "text": "JSON Parsing Demo", "variant": "h3"],
                    ["id": "t2", "component": "Text", "text": "These components were parsed from raw JSON dictionaries, exactly as they would arrive from an AI backend.", "variant": "body"],
                    ["id": "card", "component": "Card", "child": "card_col"],
                    ["id": "card_col", "component": "Column", "children": ["ct1", "ct2"]],
                    ["id": "ct1", "component": "Text", "text": "Parsed Card", "variant": "h5"],
                    ["id": "ct2", "component": "Text", "text": "✓ CreateSurface\n✓ UpdateComponents\n✓ Component.fromJSON\n✓ SurfaceController pipeline", "variant": "body"],
                    ["id": "picker", "component": "ChoicePicker", "binding": "/choice",
                     "label": "Pick a framework",
                     "options": [
                        ["label": "UIKit", "value": "uikit"],
                        ["label": "SwiftUI", "value": "swiftui"],
                        ["label": "Flutter", "value": "flutter"],
                     ] as [JsonMap]
                    ] as JsonMap
                ] as [JsonMap]
            ] as JsonMap
        ]

        let dataJSON: JsonMap = [
            "version": "v0.9",
            "updateDataModel": [
                "surfaceId": "json-demo",
                "path": "/choice",
                "value": "uikit"
            ] as JsonMap
        ]

        // Parse and handle
        if let msg1 = try? A2UIMessage.fromJSON(createJSON) { controller.handleMessage(msg1) }
        if let msg2 = try? A2UIMessage.fromJSON(updateJSON) { controller.handleMessage(msg2) }
        if let msg3 = try? A2UIMessage.fromJSON(dataJSON) { controller.handleMessage(msg3) }

        let surfaceView = SurfaceView(surfaceContext: controller.contextFor(surfaceId: "json-demo"))

        let scrollView = UIScrollView()
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        scrollView.addSubview(surfaceView)
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            surfaceView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            surfaceView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            surfaceView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            surfaceView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }
}
