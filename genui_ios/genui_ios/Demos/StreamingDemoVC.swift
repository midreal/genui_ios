import UIKit
import Combine
import A2UI

/// Demo 4: Uses MockTransport + Conversation to simulate streaming UI
/// delivery, components appear progressively with delays.
class StreamingDemoVC: UIViewController {

    private var conversation: Conversation?
    private var cancellables = Set<AnyCancellable>()
    private var surfaceView: SurfaceView?

    private lazy var statusLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.textColor = .secondaryLabel
        l.font = .preferredFont(forTextStyle: .footnote)
        l.text = "Tap 'Start Stream' to begin"
        return l
    }()

    private lazy var startButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Start Stream"
        config.cornerStyle = .medium
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: #selector(startStream), for: .touchUpInside)
        return btn
    }()

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        return sv
    }()

    private lazy var contentContainer: UIView = {
        UIView()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        layoutSubviews()
    }

    private func layoutSubviews() {
        let topStack = UIStackView(arrangedSubviews: [statusLabel, startButton])
        topStack.axis = .vertical
        topStack.spacing = 8
        topStack.alignment = .center

        view.addSubview(topStack)
        view.addSubview(scrollView)
        scrollView.addSubview(contentContainer)

        topStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            topStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentContainer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentContainer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    @objc private func startStream() {
        // Tear down previous
        conversation?.dispose()
        cancellables.removeAll()
        surfaceView?.removeFromSuperview()
        surfaceView = nil

        statusLabel.text = "Streaming..."
        startButton.isEnabled = false

        let mock = MockTransport()
        let catalog = BasicCatalog.create()
        let controller = SurfaceController(catalogs: [catalog])
        let conv = Conversation(controller: controller, transport: mock)
        self.conversation = conv

        // Observe events
        conv.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .surfaceAdded(let sid, _):
                    self?.statusLabel.text = "Surface created: \(sid)"
                    self?.attachSurface(controller: controller, surfaceId: sid)
                case .componentsUpdated(let sid, let def):
                    self?.statusLabel.text = "Updated: \(def.components.count) components in \(sid)"
                case .surfaceRemoved(let sid):
                    self?.statusLabel.text = "Surface removed: \(sid)"
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Build the streaming sequence
        let sid = "stream-demo"
        let messages: [A2UIMessage] = [
            .createSurface(CreateSurfacePayload(surfaceId: sid, catalogId: basicCatalogId)),

            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["loading_text"]
                ]),
                Component(id: "loading_text", type: "Text", properties: [
                    "text": "Thinking...", "variant": "body"
                ]),
            ])),

            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "desc"]
                ]),
                Component(id: "title", type: "Text", properties: [
                    "text": "Weather Forecast", "variant": "h3"
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "Loading forecast data...", "variant": "body"
                ]),
            ])),

            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "desc", "card1"]
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "Here is today's weather in Shanghai:", "variant": "body"
                ]),
                Component(id: "card1", type: "Card", properties: ["child": "card1_col"]),
                Component(id: "card1_col", type: "Column", properties: [
                    "children": ["card1_icon_row", "card1_temp"]
                ]),
                Component(id: "card1_icon_row", type: "Row", properties: [
                    "children": ["card1_icon", "card1_city"], "align": "center"
                ]),
                Component(id: "card1_icon", type: "Icon", properties: [
                    "icon": "wb_sunny", "size": 32, "color": "orange"
                ]),
                Component(id: "card1_city", type: "Text", properties: [
                    "text": "Shanghai", "variant": "h4"
                ]),
                Component(id: "card1_temp", type: "Text", properties: [
                    "text": "26°C  Sunny", "variant": "body"
                ]),
            ])),

            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "desc", "card1", "divider", "card2"]
                ]),
                Component(id: "divider", type: "Divider", properties: [:]),
                Component(id: "card2", type: "Card", properties: ["child": "card2_col"]),
                Component(id: "card2_col", type: "Column", properties: [
                    "children": ["card2_icon_row", "card2_temp"]
                ]),
                Component(id: "card2_icon_row", type: "Row", properties: [
                    "children": ["card2_icon", "card2_city"], "align": "center"
                ]),
                Component(id: "card2_icon", type: "Icon", properties: [
                    "icon": "cloud", "size": 32, "color": "gray"
                ]),
                Component(id: "card2_city", type: "Text", properties: [
                    "text": "Beijing", "variant": "h4"
                ]),
                Component(id: "card2_temp", type: "Text", properties: [
                    "text": "18°C  Cloudy", "variant": "body"
                ]),
            ])),

            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "desc", "card1", "divider", "card2", "done_text"]
                ]),
                Component(id: "done_text", type: "Text", properties: [
                    "text": "✅ Stream complete — all data delivered.", "variant": "body"
                ]),
            ])),
        ]

        mock.sendSequence(messages, delay: 0.8)

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(messages.count) * 0.8 + 0.5) { [weak self] in
            self?.statusLabel.text = "Stream finished ✓"
            self?.startButton.isEnabled = true
        }
    }

    private func attachSurface(controller: SurfaceController, surfaceId: String) {
        guard surfaceView == nil else { return }
        let sv = SurfaceView(surfaceContext: controller.contextFor(surfaceId: surfaceId))
        self.surfaceView = sv
        contentContainer.addSubview(sv)
        sv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 16),
            sv.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 16),
            sv.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -16),
            sv.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -16),
        ])
    }

    deinit {
        conversation?.dispose()
    }
}
