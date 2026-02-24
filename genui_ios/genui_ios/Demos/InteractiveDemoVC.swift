import UIKit
import Combine
import A2UI

/// Demo 5: Full interaction loop.
/// Renders a form, captures user events via onSubmit, and responds with
/// updated components — simulating a complete request-response cycle.
class InteractiveDemoVC: UIViewController {

    private var controller: SurfaceController!
    private var cancellables = Set<AnyCancellable>()

    private lazy var eventLog: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.textColor = .secondaryLabel
        tv.backgroundColor = .secondarySystemBackground
        tv.layer.cornerRadius = 8
        tv.layer.masksToBounds = true
        tv.text = "— Event Log —\n"
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])
        let sid = "interactive-demo"

        controller.handleMessage(.createSurface(CreateSurfacePayload(
            surfaceId: sid, catalogId: basicCatalogId
        )))

        controller.handleMessage(.updateDataModel(UpdateDataModelPayload(
            surfaceId: sid, path: .root, value: [
                "name": "",
                "email": "",
                "agree": false,
                "result": ""
            ] as JsonMap
        )))

        controller.handleMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["header", "divider0", "name_field", "email_field",
                                 "agree_check", "submit_btn", "divider1", "result_text"]
                ]),
                Component(id: "header", type: "Text", properties: [
                    "text": "Interactive Form", "variant": "h3"
                ]),
                Component(id: "divider0", type: "Divider", properties: [:]),
                Component(id: "name_field", type: "TextField", properties: [
                    "binding": "/name", "label": "Full Name"
                ]),
                Component(id: "email_field", type: "TextField", properties: [
                    "binding": "/email", "label": "Email"
                ]),
                Component(id: "agree_check", type: "CheckBox", properties: [
                    "binding": "/agree", "label": "I agree to the terms"
                ]),
                Component(id: "submit_btn", type: "Button", properties: [
                    "child": "submit_text",
                    "variant": "primary",
                    "action": ["event": ["name": "submit_form"]] as JsonMap
                ]),
                Component(id: "submit_text", type: "Text", properties: [
                    "text": "Submit"
                ]),
                Component(id: "divider1", type: "Divider", properties: [:]),
                Component(id: "result_text", type: "Text", properties: [
                    "text": ["path": "/result"] as JsonMap, "variant": "body"
                ]),
            ]
        )))

        // Listen for submit events and respond
        controller.onSubmit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleSubmitEvent(event, surfaceId: sid)
            }
            .store(in: &cancellables)

        let surfaceView = SurfaceView(surfaceContext: controller.contextFor(surfaceId: sid))

        // Layout: surface on top, event log on bottom
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        view.addSubview(eventLog)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        eventLog.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: eventLog.topAnchor, constant: -8),

            eventLog.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            eventLog.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            eventLog.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            eventLog.heightAnchor.constraint(equalToConstant: 150),
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

    private func handleSubmitEvent(_ event: UserActionEvent, surfaceId: String) {
        let data = event.data
        let logEntry = "EVENT: \(data)\n"
        eventLog.text.append(logEntry)
        let bottom = NSRange(location: eventLog.text.count - 1, length: 1)
        eventLog.scrollRangeToVisible(bottom)

        // Check if this is a form submit
        if let eventInfo = data["event"] as? JsonMap,
           let eventName = eventInfo["name"] as? String,
           eventName == "submit_form" {
            respondToFormSubmit(surfaceId: surfaceId)
        }
    }

    private func respondToFormSubmit(surfaceId: String) {
        let model = controller.store.getDataModel(surfaceId: surfaceId)
        let name = model.getValue(path: DataPath("/name")) as? String ?? ""
        let email = model.getValue(path: DataPath("/email")) as? String ?? ""
        let agree = model.getValue(path: DataPath("/agree")) as? Bool ?? false

        var resultText: String
        if name.isEmpty || email.isEmpty {
            resultText = "⚠️ Please fill in all fields."
        } else if !agree {
            resultText = "⚠️ Please agree to the terms."
        } else {
            resultText = "✅ Form submitted!\nName: \(name)\nEmail: \(email)"
        }

        model.update(path: DataPath("/result"), value: resultText)

        eventLog.text.append("RESPONSE: \(resultText)\n")
        let bottom = NSRange(location: eventLog.text.count - 1, length: 1)
        eventLog.scrollRangeToVisible(bottom)
    }
}
