import UIKit
import A2UI

/// Demo 2: Demonstrates two-way data binding between DataModel and UI.
/// TextField → DataModel → Text display; Slider; CheckBox.
class DataBindingDemoVC: UIViewController {

    private var controller: SurfaceController!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])
        let sid = "binding-demo"

        // Create surface
        controller.handleMessage(.createSurface(CreateSurfacePayload(
            surfaceId: sid, catalogId: basicCatalogId
        )))

        // Set initial data
        controller.handleMessage(.updateDataModel(UpdateDataModelPayload(
            surfaceId: sid, path: .root, value: [
                "username": "World",
                "volume": 50,
                "darkMode": false
            ] as JsonMap
        )))

        // Define components with data bindings
        let components: [Component] = [
            Component(id: "root", type: "Column", properties: [
                "children": ["header", "divider0", "name_field", "greeting", "divider1",
                             "volume_slider", "volume_text", "divider2", "dark_toggle"]
            ]),
            Component(id: "header", type: "Text", properties: [
                "text": "Data Binding Demo", "variant": "h3"
            ]),
            Component(id: "divider0", type: "Divider", properties: [:]),
            Component(id: "name_field", type: "TextField", properties: [
                "binding": "/username", "label": "Enter your name"
            ]),
            Component(id: "greeting", type: "Text", properties: [
                "text": ["path": "/username"] as JsonMap, "variant": "h4"
            ]),
            Component(id: "divider1", type: "Divider", properties: [:]),
            Component(id: "volume_slider", type: "Slider", properties: [
                "binding": "/volume", "min": 0, "max": 100, "label": "Volume"
            ]),
            Component(id: "volume_text", type: "Text", properties: [
                "text": ["path": "/volume"] as JsonMap, "variant": "body"
            ]),
            Component(id: "divider2", type: "Divider", properties: [:]),
            Component(id: "dark_toggle", type: "CheckBox", properties: [
                "binding": "/darkMode", "label": "Dark Mode"
            ]),
        ]

        controller.handleMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: sid, components: components
        )))

        let surfaceContext = controller.contextFor(surfaceId: sid)
        let surfaceView = SurfaceView(surfaceContext: surfaceContext)

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
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
