import Foundation
import Combine

/// A mock transport for testing and demos.
///
/// Loads A2UI messages from pre-defined sequences and delivers them
/// with configurable delays to simulate streaming.
public final class MockTransport: A2UITransport {

    private let messagesSubject = PassthroughSubject<A2UIMessage, Never>()
    private let textSubject = PassthroughSubject<String, Never>()
    private var receivedActions = [UserActionEvent]()
    private var workItems = [DispatchWorkItem]()

    /// Callback invoked when the mock receives a user action.
    public var onAction: ((UserActionEvent) -> Void)?

    public init() {}

    // MARK: - A2UITransport

    public var incomingMessages: AnyPublisher<A2UIMessage, Never> {
        messagesSubject.eraseToAnyPublisher()
    }

    public var incomingText: AnyPublisher<String, Never> {
        textSubject.eraseToAnyPublisher()
    }

    public func sendAction(_ event: UserActionEvent) async throws {
        receivedActions.append(event)
        onAction?(event)
    }

    public func dispose() {
        workItems.forEach { $0.cancel() }
        workItems.removeAll()
        messagesSubject.send(completion: .finished)
        textSubject.send(completion: .finished)
    }

    // MARK: - Mock API

    /// All actions received from the client.
    public var actions: [UserActionEvent] { receivedActions }

    /// Sends a single message immediately.
    public func send(_ message: A2UIMessage) {
        messagesSubject.send(message)
    }

    /// Sends text content immediately.
    public func sendText(_ text: String) {
        textSubject.send(text)
    }

    /// Sends a sequence of messages with delays between them.
    ///
    /// - Parameters:
    ///   - messages: The messages to send in order.
    ///   - delay: Seconds between each message (default 0.3).
    public func sendSequence(_ messages: [A2UIMessage], delay: TimeInterval = 0.3) {
        for (index, message) in messages.enumerated() {
            let item = DispatchWorkItem { [weak self] in
                self?.messagesSubject.send(message)
            }
            workItems.append(item)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay * Double(index),
                execute: item
            )
        }
    }

    /// Convenience: Sends a sequence from a JSON string containing A2UI messages.
    public func sendFromJSON(_ jsonString: String, delay: TimeInterval = 0.3) {
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [JsonMap] else { return }
        let messages = array.compactMap { try? A2UIMessage.fromJSON($0) }
        sendSequence(messages, delay: delay)
    }
}
