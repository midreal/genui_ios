import Foundation
import Combine

/// Push-based transport adapter that wraps `A2UIStreamParser`.
///
/// Provides `addChunk(text:)` and `addMessage(msg:)` APIs for receiving
/// data from any source, and exposes parsed messages as Combine publishers.
public final class A2UITransportAdapter {

    private let parser = A2UIStreamParser()
    private let messagesSubject = PassthroughSubject<A2UIMessage, Never>()
    private let textSubject = PassthroughSubject<String, Never>()

    public init() {}

    /// Publisher of parsed A2UI messages.
    public var messages: AnyPublisher<A2UIMessage, Never> {
        messagesSubject.eraseToAnyPublisher()
    }

    /// Publisher of non-JSON text content.
    public var text: AnyPublisher<String, Never> {
        textSubject.eraseToAnyPublisher()
    }

    /// Feeds a text chunk from the AI stream.
    public func addChunk(_ chunk: String) {
        let parsed = parser.addChunk(chunk)
        for msg in parsed {
            messagesSubject.send(msg)
        }
        let remaining = parser.remainingText
        if !remaining.isEmpty {
            textSubject.send(remaining)
        }
    }

    /// Directly adds a pre-parsed A2UI message.
    public func addMessage(_ message: A2UIMessage) {
        messagesSubject.send(message)
    }

    /// Signals that the stream has ended.
    public func complete() {
        messagesSubject.send(completion: .finished)
        textSubject.send(completion: .finished)
    }

    /// Resets the parser for a new stream.
    public func reset() {
        parser.reset()
    }
}
