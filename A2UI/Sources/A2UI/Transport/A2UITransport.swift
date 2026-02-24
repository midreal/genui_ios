import Foundation
import Combine

/// Protocol for the A2UI transport layer.
///
/// Abstracts the communication channel between the client and AI backend.
/// Implementations can be SSE, WebSocket, HTTP polling, or mock.
public protocol A2UITransport: AnyObject {
    /// Stream of parsed A2UI messages from the server.
    var incomingMessages: AnyPublisher<A2UIMessage, Never> { get }

    /// Stream of plain text from the server (chat content, not UI messages).
    var incomingText: AnyPublisher<String, Never> { get }

    /// Sends a user action event to the server.
    func sendAction(_ event: UserActionEvent) async throws

    /// Releases all resources.
    func dispose()
}
