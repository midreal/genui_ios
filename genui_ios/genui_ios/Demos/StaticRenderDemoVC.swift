import UIKit
import A2UI

/// Demo 1: Directly constructs a SurfaceDefinition and renders it
/// through SurfaceView to validate recursive UIView tree building.
class StaticRenderDemoVC: UIViewController {

    private var controller: SurfaceController!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])

        // Build a surface definition programmatically
        let definition = SurfaceDefinition(
            surfaceId: "static-demo",
            catalogId: basicCatalogId,
            components: [
                "root": Component(id: "root", type: "Column", properties: [
                    "children": ["title", "subtitle", "divider1", "card1", "row1", "btn1"]
                ]),
                "title": Component(id: "title", type: "Text", properties: [
                    "text": "A2UI Static Render",
                    "variant": "h2"
                ]),
                "subtitle": Component(id: "subtitle", type: "Text", properties: [
                    "text": "This UI is built from a SurfaceDefinition with no server. All components are statically defined in Swift code.",
                    "variant": "body"
                ]),
                "divider1": Component(id: "divider1", type: "Divider", properties: [:]),
                "card1": Component(id: "card1", type: "Card", properties: [
                    "child": "card_content"
                ]),
                "card_content": Component(id: "card_content", type: "Column", properties: [
                    "children": ["card_title", "card_body"]
                ]),
                "card_title": Component(id: "card_title", type: "Text", properties: [
                    "text": "Card Component",
                    "variant": "h4"
                ]),
                "card_body": Component(id: "card_body", type: "Text", properties: [
                    "text": "This card demonstrates the **Card** container with shadow and rounded corners.",
                    "variant": "body"
                ]),
                "row1": Component(id: "row1", type: "Row", properties: [
                    "children": ["icon_star", "icon_heart", "icon_search"],
                    "align": "center"
                ]),
                "icon_star": Component(id: "icon_star", type: "Icon", properties: [
                    "icon": "star", "size": 28, "color": "orange"
                ]),
                "icon_heart": Component(id: "icon_heart", type: "Icon", properties: [
                    "icon": "favorite", "size": 28, "color": "red"
                ]),
                "icon_search": Component(id: "icon_search", type: "Icon", properties: [
                    "icon": "search", "size": 28, "color": "blue"
                ]),
                "btn1": Component(id: "btn1", type: "Button", properties: [
                    "child": "btn1_text",
                    "variant": "primary",
                    "action": ["event": ["name": "demo_tap"]] as JsonMap
                ]),
                "btn1_text": Component(id: "btn1_text", type: "Text", properties: [
                    "text": "Primary Button"
                ]),
            ]
        )

        // Feed through the controller
        controller.handleMessage(.createSurface(CreateSurfacePayload(
            surfaceId: "static-demo",
            catalogId: basicCatalogId
        )))
        // Manually set components via update
        let components = definition.components.values.map { $0 }
        controller.handleMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: "static-demo",
            components: Array(components)
        )))

        let surfaceContext = controller.contextFor(surfaceId: "static-demo")
        let surfaceView = SurfaceView(surfaceContext: surfaceContext)

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
