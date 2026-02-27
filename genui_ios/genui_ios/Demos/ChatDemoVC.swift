import UIKit
import Combine
import A2UI

/// Chat interface with a mock AI backend that responds with A2UI components.
///
/// Demonstrates two interaction flows:
/// 1. User sends text -> backend generates a new A2UI surface as a reply
/// 2. User interacts with an A2UI component -> backend updates the surface
class ChatDemoVC: UIViewController, UITextFieldDelegate {

    private var conversation: Conversation?
    private var backend: MockChatBackend?
    private var cancellables = Set<AnyCancellable>()

    private enum ChatItem {
        case userMessage(String)
        case aiSurface(surfaceId: String)
    }
    private var chatItems: [ChatItem] = []

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .interactive
        return sv
    }()

    private lazy var chatStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        return stack
    }()

    private lazy var inputField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Type weather, form, menu, counter..."
        tf.borderStyle = .none
        tf.backgroundColor = .secondarySystemBackground
        tf.layer.cornerRadius = 20
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 0))
        tf.rightViewMode = .always
        tf.returnKeyType = .send
        tf.delegate = self
        return tf
    }()

    private lazy var sendButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        btn.setImage(UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config), for: .normal)
        btn.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var inputBar: UIView = {
        let bar = UIView()
        bar.backgroundColor = .systemBackground
        return bar
    }()

    private var inputBarBottomConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupChat()
        setupLayout()
        setupKeyboardObservers()

        addHintBanner()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        inputField.becomeFirstResponder()
    }

    deinit {
        conversation?.dispose()
    }

    // MARK: - Setup

    private func setupChat() {
        let mock = MockTransport()
        let catalog = BasicCatalog.create()
        let controller = SurfaceController(catalogs: [catalog])
        let conv = Conversation(controller: controller, transport: mock)
        self.conversation = conv
        self.backend = MockChatBackend(transport: mock, controller: controller)

        conv.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if case .componentsUpdated = event {
                    self?.refreshLayout()
                }
            }
            .store(in: &cancellables)
    }

    private func setupLayout() {
        // Input bar
        inputBar.addSubview(inputField)
        inputBar.addSubview(sendButton)
        inputField.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        let topBorder = UIView()
        topBorder.backgroundColor = .separator
        inputBar.addSubview(topBorder)
        topBorder.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: inputBar.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            inputField.topAnchor.constraint(equalTo: inputBar.topAnchor, constant: 8),
            inputField.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: 12),
            inputField.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -12),
            inputField.heightAnchor.constraint(equalToConstant: 40),
            inputField.bottomAnchor.constraint(equalTo: inputBar.bottomAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: inputField.trailingAnchor, constant: -6),
            sendButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 32),
            sendButton.heightAnchor.constraint(equalToConstant: 32),
        ])

        // Scroll + chat stack
        view.addSubview(scrollView)
        view.addSubview(inputBar)
        scrollView.addSubview(chatStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        chatStack.translatesAutoresizingMaskIntoConstraints = false

        inputBarBottomConstraint = inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBarBottomConstraint,

            chatStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            chatStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            chatStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            chatStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            chatStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -24),
        ])
    }

    private func addHintBanner() {
        let hint = UILabel()
        hint.text = "Type a command and tap send. Try: weather, form, menu, counter, survey, booking"
        hint.font = .systemFont(ofSize: 13)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0
        hint.textAlignment = .center

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 10
        container.addSubview(hint)
        hint.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            hint.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            hint.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            hint.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])
        chatStack.addArrangedSubview(container)
    }

    // MARK: - Keyboard

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        let keyboardHeight = view.frame.height - frame.origin.y - view.safeAreaInsets.bottom
        let offset = max(keyboardHeight, 0)
        UIView.animate(withDuration: duration) {
            self.inputBarBottomConstraint.constant = -offset
            self.view.layoutIfNeeded()
        }
        scrollToBottom(animated: true)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        UIView.animate(withDuration: duration) {
            self.inputBarBottomConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Send

    @objc private func sendTapped() {
        sendMessage()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }

    private func sendMessage() {
        guard let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        inputField.text = ""

        appendUserBubble(text)

        guard let backend = backend, let controller = conversation?.controller else { return }
        let surfaceId = backend.handleUserMessage(text)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.appendAISurface(surfaceId: surfaceId, controller: controller)
        }
    }

    // MARK: - Chat Bubbles

    private func appendUserBubble(_ text: String) {
        chatItems.append(.userMessage(text))

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15)
        label.textColor = .white
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        let bubble = UIView()
        bubble.backgroundColor = .systemBlue
        bubble.layer.cornerRadius = 16
        bubble.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
        ])

        let row = UIStackView(arrangedSubviews: [UIView(), bubble])
        row.axis = .horizontal
        row.alignment = .trailing
        bubble.widthAnchor.constraint(lessThanOrEqualTo: row.widthAnchor, multiplier: 0.75).isActive = true

        chatStack.addArrangedSubview(row)
        scrollToBottom(animated: true)
    }

    private func appendAISurface(surfaceId: String, controller: SurfaceController) {
        chatItems.append(.aiSurface(surfaceId: surfaceId))

        let surfaceView = SurfaceView(surfaceContext: controller.contextFor(surfaceId: surfaceId))
        surfaceView.backgroundColor = .clear

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        container.clipsToBounds = true
        container.addSubview(surfaceView)
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            surfaceView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            surfaceView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            surfaceView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])

        let row = UIStackView(arrangedSubviews: [container, UIView()])
        row.axis = .horizontal
        row.alignment = .top
        container.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.9).isActive = true

        chatStack.addArrangedSubview(row)
        scrollToBottom(animated: true)
    }

    // MARK: - Helpers

    private func scrollToBottom(animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let bottomOffset = max(self.scrollView.contentSize.height - self.scrollView.bounds.height + self.scrollView.contentInset.bottom, 0)
            self.scrollView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: animated)
        }
    }

    private func refreshLayout() {
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.15) {
            self.view.layoutIfNeeded()
        }
        scrollToBottom(animated: true)
    }
}
