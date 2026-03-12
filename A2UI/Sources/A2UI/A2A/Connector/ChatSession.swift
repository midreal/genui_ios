import Foundation
import Combine

// MARK: - ChatSession Events

/// Events emitted by `ChatSession` to drive UI updates.
public enum ChatSessionEvent {
    case userMessageAdded(text: String)
    case aiTextReceived(text: String)
    case surfaceAdded(surfaceId: String, definition: SurfaceDefinition)
    case surfaceUpdated(surfaceId: String, definition: SurfaceDefinition)
    case surfaceRemoved(surfaceId: String)
    case waiting
    case ready
    case error(Error)
}

// MARK: - ChatSession

/// High-level facade for generative UI conversations.
///
/// Matches Dart's `ChatSessionStore` + `GenUiConversation`. Wires together:
/// 1. `A2uiAgentConnector` — network communication
/// 2. `SurfaceController` — UI Surface state management
/// 3. Conversation history tracking with local persistence
/// 4. User action event routing back to the server
/// 5. Task resume after app restart
public final class ChatSession {

    // MARK: - Persistence Keys

    private static let cacheKey = "a2ui_chat_cache_v1"
    private static let titleKey = "a2ui_chat_title_v1"
    private static let taskIdKey = "a2ui_chat_task_id_v1"
    private static let contextIdKey = "a2ui_chat_context_id_v1"
    private static let awaitingKey = "a2ui_chat_awaiting_v1"
    private static let maxCachedMessages = 200

    // MARK: - Public API

    public let controller: SurfaceController
    public let connector: A2uiAgentConnector
    public private(set) var history: [ChatMessage] = []

    /// Auto-generated session title based on the first user message.
    public private(set) var sessionTitle: String = ""

    /// Whether the session is waiting for an AI response.
    public var isWaiting: Bool { isWaitingSubject.value }

    public var isWaitingPublisher: AnyPublisher<Bool, Never> {
        isWaitingSubject.eraseToAnyPublisher()
    }

    public var events: AnyPublisher<ChatSessionEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }

    // MARK: - Private

    private let eventsSubject = PassthroughSubject<ChatSessionEvent, Never>()
    private let isWaitingSubject = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()
    private let clientCapabilities: A2UiClientCapabilities
    private let defaults: UserDefaults

    private var surfaceDefinitions: [String: SurfaceDefinition] = [:]
    private var surfaceMessageIds: Set<String> = []
    private var surfacesSinceLastUser: [String] = []
    private var awaitingAssistant = false
    private var restoredTaskId: String?
    private var restoredContextId: String?
    private var cacheTimer: DispatchWorkItem?
    private var isRestoringCache = false

    // MARK: - Init

    /// Creates a `ChatSession` connected to an A2A server.
    public init(
        serverURL: URL,
        catalogs: [Catalog] = [BasicCatalog.create()],
        extraHeaders: [String: String] = [:],
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.controller = SurfaceController(catalogs: catalogs)
        self.clientCapabilities = A2UiClientCapabilities(
            supportedCatalogIds: catalogs.compactMap { $0.catalogId }
        )

        var headers = extraHeaders
        headers["X-A2A-Extensions"] = a2uiExtensionURI

        let transport = A2ASseTransport(url: serverURL.absoluteString, authHeaders: headers)
        let client = A2AClient(url: serverURL.absoluteString, transport: transport)
        self.connector = A2uiAgentConnector(url: serverURL, client: client)

        sessionTitle = Self.buildSessionTitle("Chat")
        loadCache()
        wireUp()

        if awaitingAssistant && restoredTaskId != nil {
            connector.restoreTaskState(taskId: restoredTaskId, contextId: restoredContextId)
            resumePendingTask()
        }
    }

    /// Creates a `ChatSession` with a pre-configured connector (for testing).
    public init(
        connector: A2uiAgentConnector,
        catalogs: [Catalog] = [BasicCatalog.create()],
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.connector = connector
        self.controller = SurfaceController(catalogs: catalogs)
        self.clientCapabilities = A2UiClientCapabilities(
            supportedCatalogIds: catalogs.compactMap { $0.catalogId }
        )
        sessionTitle = Self.buildSessionTitle("Chat")
        loadCache()
        wireUp()

        if awaitingAssistant && restoredTaskId != nil {
            connector.restoreTaskState(taskId: restoredTaskId, contextId: restoredContextId)
            resumePendingTask()
        }
    }

    // MARK: - Public Methods

    /// Sends a user text message and starts the AI response stream.
    public func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        history.append(.userText(trimmed))
        eventsSubject.send(.userMessageAdded(text: trimmed))
        awaitingAssistant = true
        surfacesSinceLastUser.removeAll()
        maybeAutoRenameSession(trimmed)
        isWaitingSubject.value = true
        eventsSubject.send(.waiting)
        scheduleCacheSave()

        connector.sendUserMessage(trimmed, clientCapabilities: clientCapabilities)
    }

    /// Sends a `UserActionEvent` (button click, etc.) back to the server.
    public func sendAction(_ event: UserActionEvent) {
        history.append(.userUiInteraction(parts: [.text(event.name)]))
        Task { [weak self] in
            do {
                try await self?.connector.sendUserAction(event)
            } catch {
                self?.eventsSubject.send(.error(error))
            }
        }
    }

    /// Returns a `SurfaceContext` for rendering the given surface.
    public func context(for surfaceId: String) -> SurfaceContext {
        controller.contextFor(surfaceId: surfaceId)
    }

    /// Clears all state and starts a fresh session.
    public func resetSession() {
        defaults.removeObject(forKey: Self.cacheKey)
        defaults.removeObject(forKey: Self.titleKey)
        defaults.removeObject(forKey: Self.taskIdKey)
        defaults.removeObject(forKey: Self.contextIdKey)
        defaults.removeObject(forKey: Self.awaitingKey)

        history.removeAll()
        surfaceDefinitions.removeAll()
        surfaceMessageIds.removeAll()
        surfacesSinceLastUser.removeAll()
        awaitingAssistant = false
        restoredTaskId = nil
        restoredContextId = nil
        isWaitingSubject.value = false
        sessionTitle = Self.buildSessionTitle("Chat")

        controller.dispose()
    }

    /// Releases all resources.
    public func dispose() {
        cacheTimer?.cancel()
        cancellables.removeAll()
        controller.dispose()
        connector.dispose()
    }

    // MARK: - Combine Wiring

    private func wireUp() {
        connector.incomingMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.controller.handleMessage(message)
            }
            .store(in: &cancellables)

        connector.incomingText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.handleAssistantText(text)
            }
            .store(in: &cancellables)

        connector.errorStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleAssistantError("Error: \(error.localizedDescription)")
            }
            .store(in: &cancellables)

        controller.surfaceUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self else { return }
                switch update {
                case .surfaceAdded(let surfaceId, let definition):
                    self.surfaceDefinitions[surfaceId] = definition
                    if !self.isRestoringCache && !self.surfaceMessageIds.contains(surfaceId) {
                        self.history.append(.aiUi(surfaceId: surfaceId, definition: definition))
                        self.surfaceMessageIds.insert(surfaceId)
                        if self.awaitingAssistant {
                            self.surfacesSinceLastUser.append(surfaceId)
                        }
                    }
                    self.eventsSubject.send(.surfaceAdded(surfaceId: surfaceId, definition: definition))
                    self.isWaitingSubject.value = false
                    self.eventsSubject.send(.ready)
                    self.scheduleCacheSave()

                case .componentsUpdated(let surfaceId, let definition):
                    self.surfaceDefinitions[surfaceId] = definition
                    if let idx = self.history.lastIndex(where: { $0.surfaceId == surfaceId }) {
                        self.history[idx] = .aiUi(surfaceId: surfaceId, definition: definition)
                    }
                    self.eventsSubject.send(.surfaceUpdated(surfaceId: surfaceId, definition: definition))
                    self.scheduleCacheSave()

                case .surfaceRemoved(let surfaceId):
                    self.surfaceDefinitions.removeValue(forKey: surfaceId)
                    self.history.removeAll { $0.surfaceId == surfaceId }
                    self.eventsSubject.send(.surfaceRemoved(surfaceId: surfaceId))
                    self.scheduleCacheSave()
                }
            }
            .store(in: &cancellables)

        controller.onSubmit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.sendAction(event)
            }
            .store(in: &cancellables)
    }

    // MARK: - Text/Error Handling

    private func handleAssistantText(_ text: String) {
        history.append(.aiTextMessage(text))
        if awaitingAssistant {
            moveSurfacesToEnd()
            awaitingAssistant = false
        }
        eventsSubject.send(.aiTextReceived(text: text))
        isWaitingSubject.value = false
        eventsSubject.send(.ready)
        scheduleCacheSave()
    }

    private func handleAssistantError(_ text: String) {
        history.append(.aiTextMessage(text))
        if awaitingAssistant {
            moveSurfacesToEnd()
            awaitingAssistant = false
        }
        eventsSubject.send(.error(A2AException.network(message: text)))
        isWaitingSubject.value = false
        eventsSubject.send(.ready)
        scheduleCacheSave()
    }

    // MARK: - Task Resume

    private func resumePendingTask() {
        Task { [weak self] in
            guard let self else { return }
            let text = await self.connector.resubscribeAndCollect()
            if let text, !text.isEmpty {
                DispatchQueue.main.async {
                    self.handleAssistantText(text)
                }
            } else {
                DispatchQueue.main.async {
                    if self.awaitingAssistant {
                        self.awaitingAssistant = false
                        self.isWaitingSubject.value = false
                        self.scheduleCacheSave()
                    }
                }
            }
        }
    }

    // MARK: - Session Title

    private static func buildSessionTitle(_ prefix: String) -> String {
        let now = Date()
        let cal = Calendar.current
        let month = cal.component(.month, from: now)
        let day = cal.component(.day, from: now)
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        return "\(prefix) \(month)/\(day) \(hour):\(String(format: "%02d", minute))"
    }

    private func maybeAutoRenameSession(_ userText: String) {
        guard sessionTitle.hasPrefix("Chat ") else { return }
        let userMessages = history.filter { $0.isUser }
        guard userMessages.count == 1 else { return }
        let normalized = userText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return }
        let maxLen = 28
        sessionTitle = normalized.count <= maxLen ? normalized : String(normalized.prefix(maxLen)) + "..."
    }

    // MARK: - Surface Reordering

    private func moveSurfacesToEnd() {
        guard !surfacesSinceLastUser.isEmpty else { return }
        var moved = [ChatMessage]()
        history.removeAll { msg in
            if let sid = msg.surfaceId, surfacesSinceLastUser.contains(sid) {
                moved.append(msg)
                return true
            }
            return false
        }
        history.append(contentsOf: moved)
    }

    // MARK: - Persistence

    private func scheduleCacheSave() {
        cacheTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.persistCache()
        }
        cacheTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func persistCache() {
        let list: [[String: Any]] = Array(history.prefix(Self.maxCachedMessages)).compactMap { msg in
            switch msg {
            case .user(let parts):
                let text = parts.compactMap { $0.text }.joined(separator: "\n")
                return ["kind": "text", "text": text, "is_user": true]
            case .userUiInteraction:
                return nil
            case .aiText(let parts):
                let text = parts.compactMap { $0.text }.joined(separator: "\n")
                return ["kind": "text", "text": text, "is_user": false]
            case .aiUi(let surfaceId, _):
                return ["kind": "surface", "surface_id": surfaceId, "is_user": false]
            case .internal(let text):
                return ["kind": "text", "text": text, "is_user": false]
            case .toolResponse:
                return nil
            }
        }

        if let data = try? JSONSerialization.data(withJSONObject: list),
           let str = String(data: data, encoding: .utf8) {
            defaults.set(str, forKey: Self.cacheKey)
        }
        defaults.set(sessionTitle, forKey: Self.titleKey)
        defaults.set(connector.taskId ?? "", forKey: Self.taskIdKey)
        defaults.set(connector.contextId ?? "", forKey: Self.contextIdKey)
        defaults.set(awaitingAssistant, forKey: Self.awaitingKey)
    }

    private func loadCache() {
        let cachedTitle = defaults.string(forKey: Self.titleKey)
        restoredTaskId = defaults.string(forKey: Self.taskIdKey)
        restoredContextId = defaults.string(forKey: Self.contextIdKey)
        awaitingAssistant = defaults.bool(forKey: Self.awaitingKey)

        if let tid = restoredTaskId, tid.isEmpty { restoredTaskId = nil }
        if let cid = restoredContextId, cid.isEmpty { restoredContextId = nil }

        if let title = cachedTitle, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            sessionTitle = title
        }

        guard let raw = defaults.string(forKey: Self.cacheKey),
              !raw.trimmingCharacters(in: .whitespaces).isEmpty,
              let jsonData = raw.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return
        }

        isRestoringCache = true
        defer { isRestoringCache = false }

        history.removeAll()
        surfaceMessageIds.removeAll()

        for item in decoded {
            let kind = item["kind"] as? String ?? "text"
            let isUser = item["is_user"] as? Bool ?? false

            if kind == "surface" {
                let surfaceId = item["surface_id"] as? String ?? "surface"
                if !surfaceMessageIds.contains(surfaceId) {
                    surfaceMessageIds.insert(surfaceId)
                    let def = SurfaceDefinition(surfaceId: surfaceId)
                    history.append(.aiUi(surfaceId: surfaceId, definition: def))
                }
            } else {
                let text = item["text"] as? String ?? ""
                if isUser {
                    history.append(.userText(text))
                } else {
                    history.append(.aiTextMessage(text))
                }
            }
        }
    }
}
