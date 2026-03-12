import UIKit
import Combine
import A2UI

/// Demo: v0.8 vs v0.9 Speed Comparison (Real Backend)
///
/// User describes UI → two parallel requests to the a2ui_demo server (one with X-A2UI-Version: v0.8,
/// one with v0.9) → both use the real LLM to generate A2UI JSON → two cards render side by side.
/// Compare which finishes first and how the output differs.
class V08V09CompareDemoVC: UIViewController {

    private var controllerV08: SurfaceController!
    private var controllerV09: SurfaceController!

    private var generatorV08: A2uiContentGenerator?
    private var generatorV09: A2uiContentGenerator?
    private var cancellables = Set<AnyCancellable>()
    private var startTime: CFAbsoluteTime = 0

    private let serverURL = URL(string: "http://localhost:10002")!

    // MARK: - UI

    private lazy var lastPromptLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.numberOfLines = 1
        l.text = "输入描述后点击发送"
        return l
    }()

    private lazy var inputTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "描述你想要的 UI，如：一个登录表单"
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 15)
        tf.returnKeyType = .send
        tf.delegate = self
        return tf
    }()

    private lazy var sendButton: UIButton = {
        var cfg = UIButton.Configuration.filled()
        cfg.title = "发送"
        cfg.cornerStyle = .medium
        let btn = UIButton(configuration: cfg)
        btn.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var hintLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .tertiaryLabel
        l.numberOfLines = 0
        return l
    }()

    private var cardV08: UIView!
    private var cardV09: UIView!
    private var surfaceV08: SurfaceView?
    private var surfaceV09: SurfaceView?
    private var timeLabelV08: UILabel!
    private var timeLabelV09: UILabel!
    private var loadingV08: UIActivityIndicatorView!
    private var loadingV09: UIActivityIndicatorView!

    private var currentSurfaceIdV08: String?
    private var currentSurfaceIdV09: String?

    /// Time when first A2UI JSON message arrived (for comparing JSON-out latency).
    private var jsonReadyTimeV08: CFAbsoluteTime?
    private var jsonReadyTimeV09: CFAbsoluteTime?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let catalog = BasicCatalog.create()
        controllerV08 = SurfaceController(catalogs: [catalog])
        controllerV09 = SurfaceController(catalogs: [catalog])

        setupLayout()
    }

    deinit {
        generatorV08?.dispose()
        generatorV09?.dispose()
    }

    // MARK: - Layout

    private func setupLayout() {
        let inputRow = UIStackView(arrangedSubviews: [inputTextField, sendButton])
        inputRow.axis = .horizontal
        inputRow.spacing = 8
        sendButton.setContentHuggingPriority(.required, for: .horizontal)

        let inputSection = UIStackView(arrangedSubviews: [hintLabel, inputRow])
        inputSection.axis = .vertical
        inputSection.spacing = 6
        inputSection.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        inputSection.isLayoutMarginsRelativeArrangement = true
        inputSection.backgroundColor = .secondarySystemGroupedBackground

        let cardsRow = makeCardsRow()
        cardsRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true

        let promptSection = UIStackView(arrangedSubviews: [lastPromptLabel])
        promptSection.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 4, right: 16)
        promptSection.isLayoutMarginsRelativeArrangement = true

        let mainStack = UIStackView(arrangedSubviews: [promptSection, cardsRow, inputSection])
        mainStack.axis = .vertical
        mainStack.spacing = 0

        view.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    private func makeCardsRow() -> UIView {
        cardV08 = makeCard(version: "v0.8")
        cardV09 = makeCard(version: "v0.9")

        timeLabelV08 = UILabel()
        timeLabelV08.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        timeLabelV08.textColor = .secondaryLabel
        timeLabelV08.text = "—"
        loadingV08 = UIActivityIndicatorView(style: .medium)
        loadingV08.hidesWhenStopped = true

        timeLabelV09 = UILabel()
        timeLabelV09.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        timeLabelV09.textColor = .secondaryLabel
        timeLabelV09.text = "—"
        loadingV09 = UIActivityIndicatorView(style: .medium)
        loadingV09.hidesWhenStopped = true

        let headerV08 = makeCardHeader("v0.8", timeLabel: timeLabelV08, loading: loadingV08)
        let headerV09 = makeCardHeader("v0.9", timeLabel: timeLabelV09, loading: loadingV09)

        let stackV08 = UIStackView(arrangedSubviews: [headerV08, cardV08])
        stackV08.axis = .vertical
        stackV08.spacing = 6
        stackV08.layer.cornerRadius = 12
        stackV08.backgroundColor = .secondarySystemGroupedBackground
        stackV08.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 12, right: 12)
        stackV08.isLayoutMarginsRelativeArrangement = true

        let stackV09 = UIStackView(arrangedSubviews: [headerV09, cardV09])
        stackV09.axis = .vertical
        stackV09.spacing = 6
        stackV09.layer.cornerRadius = 12
        stackV09.backgroundColor = .secondarySystemGroupedBackground
        stackV09.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 12, right: 12)
        stackV09.isLayoutMarginsRelativeArrangement = true

        let row = UIStackView(arrangedSubviews: [stackV08, stackV09])
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        row.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        row.isLayoutMarginsRelativeArrangement = true
        return row
    }

    private func makeCardHeader(_ title: String, timeLabel: UILabel, loading: UIActivityIndicatorView) -> UIView {
        let titleL = UILabel()
        titleL.text = title
        titleL.font = .systemFont(ofSize: 13, weight: .semibold)
        titleL.textColor = .secondaryLabel

        let row = UIStackView(arrangedSubviews: [titleL, loading, timeLabel])
        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .center
        return row
    }

    private func makeCard(version: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .tertiarySystemBackground
        container.layer.cornerRadius = 8
        container.clipsToBounds = true

        let placeholder = UILabel()
        placeholder.text = "等待生成…"
        placeholder.font = .systemFont(ofSize: 13)
        placeholder.textColor = .tertiaryLabel
        placeholder.tag = 999
        container.addSubview(placeholder)
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    // MARK: - Actions

    @objc private func sendTapped() {
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return
        }
        inputTextField.text = nil
        view.endEditing(true)

        lastPromptLabel.text = "你: \(text)"
        sendToBothVersions(userText: text)
    }

    private func sendToBothVersions(userText: String) {
        sendButton.isEnabled = false
        cancellables.removeAll()
        resetCards()

        startTime = CFAbsoluteTimeGetCurrent()
        jsonReadyTimeV08 = nil
        jsonReadyTimeV09 = nil
        loadingV08.startAnimating()
        loadingV09.startAnimating()
        timeLabelV08.text = "请求中…"
        timeLabelV09.text = "请求中…"

        // Connectors with version headers + gallery mode (no tools)
        let headersV08: [String: String] = [
            "X-A2UI-Version": "v0.8",
            "X-A2UI-Use-Tools": "false",
        ]
        let headersV09: [String: String] = [
            "X-A2UI-Version": "v0.9",
            "X-A2UI-Use-Tools": "false",
        ]

        let connectorV08 = A2uiAgentConnector(url: serverURL, extraHeaders: headersV08)
        let connectorV09 = A2uiAgentConnector(url: serverURL, extraHeaders: headersV09)

        generatorV08 = A2uiContentGenerator(serverURL: serverURL, connector: connectorV08)
        generatorV09 = A2uiContentGenerator(serverURL: serverURL, connector: connectorV09)

        guard let gen08 = generatorV08, let gen09 = generatorV09 else { return }

        // Subscribe v0.8
        gen08.a2uiMessageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleMessage(message, isV08: true)
            }
            .store(in: &cancellables)

        gen08.isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] processing in
                guard let self else { return }
                if !processing {
                    self.loadingV08.stopAnimating()
                    let total = CFAbsoluteTimeGetCurrent() - self.startTime
                    if let json = self.jsonReadyTimeV08 {
                        let jsonElapsed = json - self.startTime
                        self.timeLabelV08.text = String(format: "JSON: %.2fs / 总: %.2fs", jsonElapsed, total)
                    } else {
                        self.timeLabelV08.text = String(format: "✓ %.2fs", total)
                    }
                    self.maybeReenableSendButton()
                }
            }
            .store(in: &cancellables)

        gen08.errorStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error, isV08: true)
            }
            .store(in: &cancellables)

        // Subscribe v0.9
        gen09.a2uiMessageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleMessage(message, isV08: false)
            }
            .store(in: &cancellables)

        gen09.isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] processing in
                guard let self else { return }
                if !processing {
                    self.loadingV09.stopAnimating()
                    let total = CFAbsoluteTimeGetCurrent() - self.startTime
                    if let json = self.jsonReadyTimeV09 {
                        let jsonElapsed = json - self.startTime
                        self.timeLabelV09.text = String(format: "JSON: %.2fs / 总: %.2fs", jsonElapsed, total)
                    } else {
                        self.timeLabelV09.text = String(format: "✓ %.2fs", total)
                    }
                    self.maybeReenableSendButton()
                }
            }
            .store(in: &cancellables)

        gen09.errorStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error, isV08: false)
            }
            .store(in: &cancellables)

        // Send both in parallel
        Task {
            async let r1 = gen08.sendRequest(.userText(userText), history: [], clientCapabilities: nil)
            async let r2 = gen09.sendRequest(.userText(userText), history: [], clientCapabilities: nil)
            _ = await (r1, r2)
        }
    }

    private func maybeReenableSendButton() {
        let v08Done = !(loadingV08.isAnimating)
        let v09Done = !(loadingV09.isAnimating)
        if v08Done && v09Done {
            sendButton.isEnabled = true
        }
    }

    private func handleMessage(_ message: A2UIMessage, isV08: Bool) {
        let surfaceId = message.surfaceId
        let now = CFAbsoluteTimeGetCurrent()
        if isV08 {
            // Mark JSON first-arrival time (for v0.8 vs v0.9 comparison)
            if jsonReadyTimeV08 == nil {
                jsonReadyTimeV08 = now
                let elapsed = now - startTime
                timeLabelV08.text = String(format: "JSON: %.2fs", elapsed)
            }
            controllerV08.handleMessage(message)
            if case .createSurface(let p) = message { currentSurfaceIdV08 = p.surfaceId }
            if surfaceV08 == nil {
                attachSurface(surfaceId: surfaceId, card: cardV08, surfaceView: &surfaceV08, controller: controllerV08)
            }
        } else {
            // Mark JSON first-arrival time (for v0.8 vs v0.9 comparison)
            if jsonReadyTimeV09 == nil {
                jsonReadyTimeV09 = now
                let elapsed = now - startTime
                timeLabelV09.text = String(format: "JSON: %.2fs", elapsed)
            }
            controllerV09.handleMessage(message)
            if case .createSurface(let p) = message { currentSurfaceIdV09 = p.surfaceId }
            if surfaceV09 == nil {
                attachSurface(surfaceId: surfaceId, card: cardV09, surfaceView: &surfaceV09, controller: controllerV09)
            }
        }
    }

    private func handleError(_ error: ContentGeneratorError, isV08: Bool) {
        if isV08 {
            loadingV08.stopAnimating()
            timeLabelV08.text = "❌ 失败"
        } else {
            loadingV09.stopAnimating()
            timeLabelV09.text = "❌ 失败"
        }
        maybeReenableSendButton()
    }

    private func attachSurface(
        surfaceId: String,
        card: UIView,
        surfaceView: inout SurfaceView?,
        controller: SurfaceController
    ) {
        card.viewWithTag(999)?.isHidden = true
        surfaceView?.removeFromSuperview()
        surfaceView = nil

        let sv = SurfaceView(surfaceContext: controller.contextFor(surfaceId: surfaceId))
        surfaceView = sv
        card.addSubview(sv)
        sv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            sv.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 4),
            sv.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            sv.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
        ])
    }

    private func resetCards() {
        let sid08 = currentSurfaceIdV08
        let sid09 = currentSurfaceIdV09
        currentSurfaceIdV08 = nil
        currentSurfaceIdV09 = nil

        surfaceV08?.removeFromSuperview()
        surfaceV09?.removeFromSuperview()
        surfaceV08 = nil
        surfaceV09 = nil

        if let s = sid08 {
            controllerV08.handleMessage(.deleteSurface(surfaceId: s))
        }
        if let s = sid09 {
            controllerV09.handleMessage(.deleteSurface(surfaceId: s))
        }

        cardV08.viewWithTag(999)?.isHidden = false
        cardV09.viewWithTag(999)?.isHidden = false
    }
}

// MARK: - UITextFieldDelegate

extension V08V09CompareDemoVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}
