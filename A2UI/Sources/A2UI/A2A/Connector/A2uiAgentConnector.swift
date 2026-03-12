import Foundation
import Combine

/// A2UI extension URI sent to the server to indicate A2UI protocol support.
public let a2uiExtensionURI = "https://a2ui.org/a2a-extension/a2ui/v0.8"

/// Connects to an A2UI Agent endpoint and streams A2UI protocol messages.
///
/// Matches Dart's `A2uiAgentConnector`. Responsibilities:
/// - Build and send JSON-RPC `message/stream` requests
/// - Parse SSE-streamed `A2AEvent` responses
/// - Extract A2UI messages from `data` parts and forward them
/// - Send user action events back to the server via `message/send`
public final class A2uiAgentConnector {

    // MARK: - Public Properties

    public let url: URL
    public private(set) var contextId: String?
    public private(set) var taskId: String?

    /// The underlying A2A client for JSON-RPC communication.
    public let client: A2AClient

    // MARK: - Streams

    private let messagesController = PassthroughSubject<A2UIMessage, Never>()
    private let errorController = PassthroughSubject<Error, Never>()
    private let textController = PassthroughSubject<String, Never>()

    /// Stream of parsed A2UI messages from the server.
    public var stream: AnyPublisher<A2UIMessage, Never> {
        messagesController.eraseToAnyPublisher()
    }

    /// Stream of errors from the A2A connection.
    public var errorStream: AnyPublisher<Error, Never> {
        errorController.eraseToAnyPublisher()
    }

    /// Stream of text responses from the server.
    public var incomingText: AnyPublisher<String, Never> {
        textController.eraseToAnyPublisher()
    }

    /// Alias for backward compatibility with `ChatSession`.
    public var incomingMessages: AnyPublisher<A2UIMessage, Never> { stream }

    // MARK: - Private

    private var activeStreamTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates a connector with an explicit `A2AClient`.
    public init(url: URL, client: A2AClient, contextId: String? = nil) {
        self.url = url
        self.client = client
        self._contextId = contextId
    }

    /// Creates a connector with default configuration.
    public init(url: URL, extraHeaders: [String: String] = [:]) {
        self.url = url
        var headers = extraHeaders
        headers["X-A2A-Extensions"] = a2uiExtensionURI
        let transport = A2ASseTransport(url: url.absoluteString, authHeaders: headers)
        self.client = A2AClient(url: url.absoluteString, transport: transport)
    }

    // MARK: - State Restoration

    /// Restores task/context state (e.g., after app restart).
    public func restoreTaskState(taskId: String?, contextId: String?) {
        self.taskId = taskId
        self._contextId = contextId
    }

    private var _contextId: String? {
        get { contextId }
        set { contextId = newValue }
    }

    // MARK: - Agent Card

    public func getAgentCard() async throws -> AgentCard {
        try await client.getAgentCard()
    }

    // MARK: - Send & Receive

    /// Sends a user message and consumes the SSE event stream.
    /// Returns the final text response, if any.
    @discardableResult
    public func connectAndSend(
        _ text: String,
        clientCapabilities: A2UiClientCapabilities? = nil
    ) async -> String? {
        let parts: [A2APart] = [.text(text)]
        return await sendParts(parts, clientCapabilities: clientCapabilities)
    }

    /// Sends message parts and consumes the event stream. Returns final text response.
    private func sendParts(
        _ parts: [A2APart],
        clientCapabilities: A2UiClientCapabilities? = nil
    ) async -> String? {
        let message = buildMessage(parts: parts, clientCapabilities: clientCapabilities)
        let events = client.messageStream(message)
        return await consumeEvents(events)
    }

    /// Resubscribes to an ongoing task and collects remaining events.
    /// Returns the final text response, if any.
    public func resubscribeAndCollect() async -> String? {
        guard let taskId else { return nil }
        let events = client.resubscribeToTask(taskId)
        return await consumeEvents(events)
    }

    /// Opens a non-blocking SSE stream for a user message (used by ChatSession).
    public func sendUserMessage(
        _ text: String,
        clientCapabilities: A2UiClientCapabilities? = nil
    ) {
        activeStreamTask?.cancel()
        activeStreamTask = Task { [weak self] in
            await self?.connectAndSend(text, clientCapabilities: clientCapabilities)
        }
    }

    // MARK: - Send User Action

    /// Sends a user interaction event (button click, form submit, etc.) to the server.
    public func sendUserAction(_ event: UserActionEvent) async throws {
        guard let taskId else {
            let dataPart = A2APart.data(event.toJSON())
            let message = buildMessage(parts: [dataPart])
            _ = try await client.messageSend(message)
            return
        }

        let clientEvent: JsonMap = [
            "actionName": event.name,
            "sourceComponentId": event.sourceComponentId,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "resolvedContext": event.context
        ]

        let dataPart = A2APart.data(["a2uiEvent": clientEvent])
        let message = buildMessage(parts: [dataPart], referenceTaskIds: [taskId])
        _ = try await client.messageSend(message)
    }

    // MARK: - Dispose

    public func dispose() {
        activeStreamTask?.cancel()
        activeStreamTask = nil
        client.close()
        messagesController.send(completion: .finished)
        errorController.send(completion: .finished)
        textController.send(completion: .finished)
    }

    // MARK: - Private Helpers

    private func buildMessage(
        parts: [A2APart],
        clientCapabilities: A2UiClientCapabilities? = nil,
        referenceTaskIds: [String]? = nil
    ) -> A2AMessage {
        var metadata: JsonMap? = nil
        if let caps = clientCapabilities {
            metadata = ["a2uiClientCapabilities": caps.toJSON()]
        }
        return A2AMessage(
            role: .user,
            parts: parts,
            contextId: contextId,
            referenceTaskIds: referenceTaskIds ?? (taskId.map { [$0] }),
            extensions: [a2uiExtensionURI],
            metadata: metadata
        )
    }

    /// Consumes an async stream of A2A events, extracting A2UI messages and text.
    private func consumeEvents(_ events: AsyncThrowingStream<A2AEvent, Error>) async -> String? {
        var responseText: String? = nil
        var finalResponse: A2AMessage? = nil

        do {
            for try await event in events {
                let status: A2ATaskStatus
                switch event {
                case .statusUpdate(let tid, let cid, let s, _):
                    taskId = tid
                    _contextId = cid
                    status = s
                case .taskStatusUpdate(let tid, let cid, let s, _):
                    taskId = tid
                    _contextId = cid
                    status = s
                case .artifactUpdate:
                    continue
                }

                if status.state.isError {
                    let errorMessage = "A2A Error: \(status.state.rawValue): \(status.message?.parts.first.map { "\($0)" } ?? "")"
                    DispatchQueue.main.async { [weak self] in
                        self?.errorController.send(A2AException.jsonRpc(code: -1, message: errorMessage, data: nil))
                    }
                    continue
                }

                guard let message = status.message else { continue }
                finalResponse = message

                for part in message.parts {
                    if case .data(let data, _) = part {
                        processA2uiMessages(data)
                    }
                }
            }

            if let finalResponse {
                for part in finalResponse.parts {
                    if case .text(let text, _) = part {
                        responseText = text
                        DispatchQueue.main.async { [weak self] in
                            self?.textController.send(text)
                        }
                    }
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorController.send(error)
            }
        }

        return responseText
    }

    private func processA2uiMessages(_ data: JsonMap) {
        let knownKeys: Set<String> = [
            "createSurface", "updateComponents", "updateDataModel", "deleteSurface",
            "beginRendering", "surfaceUpdate", "dataModelUpdate",
        ]
        guard !data.keys.filter({ knownKeys.contains($0) }).isEmpty else { return }

        do {
            let a2uiMsg = try A2UIMessage.fromJSON(data)
            DispatchQueue.main.async { [weak self] in
                self?.messagesController.send(a2uiMsg)
            }
        } catch {
            NSLog("[A2uiAgentConnector] Failed to parse A2UI message: \(error)")
        }
    }
}
