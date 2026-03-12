import UIKit
import Combine
import A2UI

/// Demo: A2UI Writing Capability (Real Backend)
///
/// Connects to the a2ui_demo Python server (localhost:10002) via the A2A protocol.
/// The user types a description of the UI they want; the LLM generates A2UI messages
/// that are streamed back in real time and rendered live on the left panel.
/// The right panel shows the raw JSON stream as it arrives.
class A2UIWritingDemoVC: UIViewController {

    // MARK: - State

    private var controller: SurfaceController!
    private var cancellables = Set<AnyCancellable>()
    private var generatorCancellables = Set<AnyCancellable>()
    private var currentSurfaceView: SurfaceView?
    private var currentSurfaceId: String?
    private var messageCount = 0

    private var contentGenerator: A2uiContentGenerator?
    private let serverURL = URL(string: "http://localhost:10002")!

    private var jsonLines: [String] = []

    // MARK: - UI: Input area

    private lazy var inputTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "描述你想要的 UI，例如：一个登录表单"
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 14)
        tf.returnKeyType = .send
        tf.clearButtonMode = .whileEditing
        tf.delegate = self
        return tf
    }()

    private lazy var sendButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "发送"
        config.cornerStyle = .medium
        config.baseBackgroundColor = .systemBlue
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var resetButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "↺ 重置"
        config.cornerStyle = .medium
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var statusLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.text = "Ready — 输入描述后点击发送"
        l.numberOfLines = 2
        return l
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        return ai
    }()

    // Left: live surface
    private lazy var surfaceContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        return v
    }()

    private lazy var surfacePlaceholder: UILabel = {
        let l = UILabel()
        l.text = "UI will appear here"
        l.font = .systemFont(ofSize: 14)
        l.textColor = .tertiaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    // Right: JSON stream log
    private lazy var jsonLogView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        tv.textColor = .label
        tv.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.1, alpha: 1)
                : UIColor(white: 0.97, alpha: 1)
        }
        tv.layer.cornerRadius = 8
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.text = ""
        return tv
    }()

    private lazy var jsonHeaderLabel: UILabel = {
        let l = UILabel()
        l.text = "JSON Stream"
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .secondaryLabel
        return l
    }()

    private lazy var copyJsonButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "doc.on.doc")
        config.baseForegroundColor = .secondaryLabel
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: #selector(copyJSON), for: .touchUpInside)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupController()
        buildLayout()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    deinit {
        contentGenerator?.dispose()
    }

    // MARK: - Setup

    private func setupController() {
        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])
    }

    // MARK: - Layout

    private func buildLayout() {
        // Input row: text field + send button
        let inputRow = UIStackView(arrangedSubviews: [inputTextField, sendButton])
        inputRow.axis = .horizontal
        inputRow.spacing = 8
        inputRow.alignment = .fill
        sendButton.setContentHuggingPriority(.required, for: .horizontal)
        sendButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Status row: activity + label + reset
        let statusRow = UIStackView(arrangedSubviews: [activityIndicator, statusLabel, UIView(), resetButton])
        statusRow.axis = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .center

        let topStack = UIStackView(arrangedSubviews: [inputRow, statusRow])
        topStack.axis = .vertical
        topStack.spacing = 8
        topStack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 8, right: 16)
        topStack.isLayoutMarginsRelativeArrangement = true

        // Surface placeholder
        surfaceContainer.addSubview(surfacePlaceholder)
        surfacePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            surfacePlaceholder.centerXAnchor.constraint(equalTo: surfaceContainer.centerXAnchor),
            surfacePlaceholder.centerYAnchor.constraint(equalTo: surfaceContainer.centerYAnchor),
            surfacePlaceholder.leadingAnchor.constraint(greaterThanOrEqualTo: surfaceContainer.leadingAnchor, constant: 16),
            surfacePlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: surfaceContainer.trailingAnchor, constant: -16),
        ])

        // JSON header row
        let jsonHeader = UIStackView(arrangedSubviews: [jsonHeaderLabel, UIView(), copyJsonButton])
        jsonHeader.axis = .horizontal
        jsonHeader.alignment = .center

        let jsonStack = UIStackView(arrangedSubviews: [jsonHeader, jsonLogView])
        jsonStack.axis = .vertical
        jsonStack.spacing = 4

        // Main split: surface | json
        let splitStack = UIStackView(arrangedSubviews: [surfaceContainer, jsonStack])
        splitStack.axis = .horizontal
        splitStack.spacing = 10
        splitStack.distribution = .fillEqually
        splitStack.alignment = .fill

        // Scroll wrapper
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        let contentStack = UIStackView(arrangedSubviews: [topStack, splitStack])
        contentStack.axis = .vertical
        contentStack.spacing = 8

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            splitStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 420),
            jsonLogView.heightAnchor.constraint(greaterThanOrEqualToConstant: 360),
        ])
    }

    // MARK: - Actions

    @objc private func sendTapped() {
        sendRequest()
    }

    @objc private func resetTapped() {
        resetState()
    }

    @objc private func copyJSON() {
        UIPasteboard.general.string = jsonLines.joined(separator: "\n")
        let alert = UIAlertController(title: nil, message: "Copied to clipboard", preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { alert.dismiss(animated: true) }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Send Request

    private func sendRequest() {
        let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            statusLabel.text = "请先输入 UI 描述"
            return
        }

        view.endEditing(true)
        resetSurface()

        // Dispose previous generator
        contentGenerator?.dispose()
        generatorCancellables.removeAll()

        let generator = A2uiContentGenerator(serverURL: serverURL)
        contentGenerator = generator

        // Subscribe to A2UI messages
        generator.a2uiMessageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &generatorCancellables)

        // Subscribe to text response
        generator.textResponseStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] responseText in
                guard let self else { return }
                let header = "// ── AI Response ──"
                let entry = "\(header)\n\(responseText)\n"
                self.jsonLines.append(entry)
                let attr = NSMutableAttributedString()
                let headerAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: UIColor.systemGreen,
                ]
                attr.append(NSAttributedString(string: header + "\n", attributes: headerAttr))
                let bodyAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel,
                ]
                attr.append(NSAttributedString(string: responseText + "\n\n", attributes: bodyAttr))
                let combined = NSMutableAttributedString(attributedString: self.jsonLogView.attributedText ?? NSAttributedString())
                combined.append(attr)
                self.jsonLogView.attributedText = combined
                let bottom = NSRange(location: self.jsonLogView.text.count - 1, length: 1)
                self.jsonLogView.scrollRangeToVisible(bottom)
            }
            .store(in: &generatorCancellables)

        // Subscribe to error stream
        generator.errorStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &generatorCancellables)

        // Subscribe to processing state
        generator.isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] processing in
                guard let self else { return }
                if processing {
                    self.activityIndicator.startAnimating()
                    self.sendButton.isEnabled = false
                    self.statusLabel.text = "Connecting to server..."
                } else {
                    self.activityIndicator.stopAnimating()
                    self.sendButton.isEnabled = true
                    if self.messageCount > 0 {
                        self.statusLabel.text = "✅ Done — \(self.messageCount) messages received"
                    } else {
                        self.statusLabel.text = "Done"
                    }
                }
            }
            .store(in: &generatorCancellables)

        Task {
            await generator.sendRequest(
                .userText(text),
                history: [],
                clientCapabilities: nil
            )
        }
    }

    // MARK: - Message Handling

    private func handleIncomingMessage(_ message: A2UIMessage) {
        if case .createSurface(let p) = message {
            controller.handleMessage(message)
            attachSurface(surfaceId: p.surfaceId)
            currentSurfaceId = p.surfaceId
            statusLabel.text = "Streaming UI..."
        } else {
            controller.handleMessage(message)
        }
        messageCount += 1
        appendJSON(message, label: message.typeName)
    }

    private func handleError(_ error: ContentGeneratorError) {
        activityIndicator.stopAnimating()
        sendButton.isEnabled = true

        let msg = error.localizedDescription
        statusLabel.text = "❌ Error: \(msg)"

        // Log error to JSON panel
        let header = "// ── Error ──"
        let entry = "\(header)\n\(msg)\n"
        jsonLines.append(entry)
        let attr = NSMutableAttributedString()
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.systemRed,
        ]
        attr.append(NSAttributedString(string: header + "\n", attributes: headerAttr))
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.systemRed,
        ]
        attr.append(NSAttributedString(string: msg + "\n\n", attributes: bodyAttr))
        let combined = NSMutableAttributedString(attributedString: jsonLogView.attributedText ?? NSAttributedString())
        combined.append(attr)
        jsonLogView.attributedText = combined
        let bottom = NSRange(location: jsonLogView.text.count - 1, length: 1)
        jsonLogView.scrollRangeToVisible(bottom)
    }

    // MARK: - Surface Attachment

    private func attachSurface(surfaceId: String) {
        currentSurfaceView?.removeFromSuperview()
        currentSurfaceView = nil
        surfacePlaceholder.isHidden = true

        let sv = SurfaceView(surfaceContext: controller.contextFor(surfaceId: surfaceId))
        currentSurfaceView = sv
        surfaceContainer.addSubview(sv)
        sv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: surfaceContainer.topAnchor, constant: 12),
            sv.leadingAnchor.constraint(equalTo: surfaceContainer.leadingAnchor, constant: 12),
            sv.trailingAnchor.constraint(equalTo: surfaceContainer.trailingAnchor, constant: -12),
            sv.bottomAnchor.constraint(lessThanOrEqualTo: surfaceContainer.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Reset

    private func resetState() {
        contentGenerator?.dispose()
        contentGenerator = nil
        generatorCancellables.removeAll()

        resetSurface()
        inputTextField.text = ""
        statusLabel.text = "Ready — 输入描述后点击发送"
        sendButton.isEnabled = true
        activityIndicator.stopAnimating()
    }

    private func resetSurface() {
        if let sid = currentSurfaceId {
            controller.handleMessage(.deleteSurface(surfaceId: sid))
        }
        currentSurfaceView?.removeFromSuperview()
        currentSurfaceView = nil
        currentSurfaceId = nil
        surfacePlaceholder.isHidden = false
        messageCount = 0

        jsonLines = []
        jsonLogView.text = ""

        setupController()
    }

    // MARK: - JSON Logging

    private func appendJSON(_ message: A2UIMessage, label: String) {
        let json = messageToJSON(message)
        let header = "// ── \(label) ──"
        let entry = "\(header)\n\(json)\n"
        jsonLines.append(entry)

        let attributed = buildAttributedJSON(header: header, body: json)
        let current = jsonLogView.attributedText ?? NSAttributedString()
        let combined = NSMutableAttributedString(attributedString: current)
        combined.append(attributed)
        jsonLogView.attributedText = combined

        let bottom = NSRange(location: jsonLogView.text.count - 1, length: 1)
        jsonLogView.scrollRangeToVisible(bottom)
    }

    private func buildAttributedJSON(header: String, body: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.systemGreen,
        ]
        result.append(NSAttributedString(string: header + "\n", attributes: headerAttr))

        let lines = body.components(separatedBy: "\n")
        for line in lines {
            result.append(highlightJSONLine(line))
            result.append(NSAttributedString(string: "\n"))
        }
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    private func highlightJSONLine(_ line: String) -> NSAttributedString {
        let base: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.label,
        ]
        let keyColor = UIColor.systemBlue
        let stringColor = UIColor.systemOrange
        let numberColor = UIColor.systemPurple

        let result = NSMutableAttributedString(string: line, attributes: base)

        let keyPattern = #""([^"]+)"\s*:"#
        if let regex = try? NSRegularExpression(pattern: keyPattern) {
            let range = NSRange(line.startIndex..., in: line)
            for match in regex.matches(in: line, range: range) {
                if let r = Range(match.range(at: 1), in: line) {
                    result.addAttribute(.foregroundColor, value: keyColor, range: NSRange(r, in: line))
                }
            }
        }

        let strPattern = #":\s*"([^"]*)"#
        if let regex = try? NSRegularExpression(pattern: strPattern) {
            let range = NSRange(line.startIndex..., in: line)
            for match in regex.matches(in: line, range: range) {
                if let r = Range(match.range(at: 1), in: line) {
                    result.addAttribute(.foregroundColor, value: stringColor, range: NSRange(r, in: line))
                }
            }
        }

        let numPattern = #":\s*(-?\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: numPattern) {
            let range = NSRange(line.startIndex..., in: line)
            for match in regex.matches(in: line, range: range) {
                if let r = Range(match.range(at: 1), in: line) {
                    result.addAttribute(.foregroundColor, value: numberColor, range: NSRange(r, in: line))
                }
            }
        }

        return result
    }

    private func messageToJSON(_ message: A2UIMessage) -> String {
        var dict: JsonMap = ["version": "v0.9"]
        switch message {
        case .createSurface(let p):
            dict["createSurface"] = ["surfaceId": p.surfaceId, "catalogId": p.catalogId] as JsonMap
        case .updateComponents(let p):
            dict["updateComponents"] = [
                "surfaceId": p.surfaceId,
                "components": p.components.map { $0.toJSON() }
            ] as JsonMap
        case .updateDataModel(let p):
            var payload: JsonMap = ["surfaceId": p.surfaceId, "path": p.path.description]
            if let val = p.value {
                payload["value"] = val
            }
            dict["updateDataModel"] = payload
        case .deleteSurface(let sid):
            dict["deleteSurface"] = ["surfaceId": sid] as JsonMap
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}

// MARK: - UITextFieldDelegate

extension A2UIWritingDemoVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendRequest()
        return true
    }
}
