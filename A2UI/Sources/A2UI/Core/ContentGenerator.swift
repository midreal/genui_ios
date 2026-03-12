import Foundation
import Combine

/// An error produced by a `ContentGenerator`.
public struct ContentGeneratorError: LocalizedError {
    public let error: Error
    public let context: String?

    public init(_ error: Error, context: String? = nil) {
        self.error = error
        self.context = context
    }

    public var errorDescription: String? {
        if let context {
            return "ContentGeneratorError (\(context)): \(error.localizedDescription)"
        }
        return "ContentGeneratorError: \(error.localizedDescription)"
    }
}

/// Abstract interface for a content generator.
///
/// Matches Dart's `ContentGenerator`. A content generator produces UI content
/// and handles user interactions. Implementations include `A2uiContentGenerator`
/// (A2A protocol) or could include direct LLM call implementations.
public protocol ContentGenerator: AnyObject {
    /// Stream of parsed A2UI messages from the generator.
    var a2uiMessageStream: AnyPublisher<A2UIMessage, Never> { get }

    /// Stream of text responses from the agent.
    var textResponseStream: AnyPublisher<String, Never> { get }

    /// Stream of errors from the agent.
    var errorStream: AnyPublisher<ContentGeneratorError, Never> { get }

    /// Whether the generator is currently processing a request.
    var isProcessing: AnyPublisher<Bool, Never> { get }

    /// Current processing state.
    var isProcessingValue: Bool { get }

    /// Sends a message to generate a response.
    ///
    /// Stateful implementations (like A2A) may ignore the `history` parameter.
    func sendRequest(
        _ message: ChatMessage,
        history: [ChatMessage],
        clientCapabilities: A2UiClientCapabilities?
    ) async

    /// Releases resources.
    func dispose()
}
