import Foundation
import Combine

/// A `ContentGenerator` that connects to an A2UI server via the A2A protocol.
///
/// Matches Dart's `A2uiContentGenerator`. Wraps an `A2uiAgentConnector` and
/// exposes it through the generic `ContentGenerator` interface.
public final class A2uiContentGenerator: ContentGenerator {

    public let connector: A2uiAgentConnector

    private let textController = PassthroughSubject<String, Never>()
    private let errorController = PassthroughSubject<ContentGeneratorError, Never>()
    private let processingSubject = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()

    public init(serverURL: URL, connector: A2uiAgentConnector? = nil) {
        self.connector = connector ?? A2uiAgentConnector(url: serverURL)

        self.connector.errorStream
            .sink { [weak self] error in
                self?.errorController.send(ContentGeneratorError(error))
            }
            .store(in: &cancellables)
    }

    // MARK: - ContentGenerator

    public var a2uiMessageStream: AnyPublisher<A2UIMessage, Never> {
        connector.stream
    }

    public var textResponseStream: AnyPublisher<String, Never> {
        textController.eraseToAnyPublisher()
    }

    public var errorStream: AnyPublisher<ContentGeneratorError, Never> {
        errorController.eraseToAnyPublisher()
    }

    public var isProcessing: AnyPublisher<Bool, Never> {
        processingSubject.eraseToAnyPublisher()
    }

    public var isProcessingValue: Bool {
        processingSubject.value
    }

    public func sendRequest(
        _ message: ChatMessage,
        history: [ChatMessage] = [],
        clientCapabilities: A2UiClientCapabilities? = nil
    ) async {
        processingSubject.value = true
        defer { processingSubject.value = false }

        let text: String
        switch message {
        case .user(let parts), .userUiInteraction(let parts):
            text = parts.compactMap { $0.text }.joined(separator: "\n")
        case .internal(let t):
            text = t
        default:
            return
        }

        guard !text.isEmpty else { return }

        let responseText = await connector.connectAndSend(text, clientCapabilities: clientCapabilities)
        if let responseText, !responseText.isEmpty {
            textController.send(responseText)
        }
    }

    /// Resubscribes to a pending task (e.g., after app restart).
    public func resumePendingTask() async {
        processingSubject.value = true
        defer { processingSubject.value = false }

        let responseText = await connector.resubscribeAndCollect()
        if let responseText, !responseText.isEmpty {
            textController.send(responseText)
        }
    }

    public func dispose() {
        cancellables.removeAll()
        textController.send(completion: .finished)
        errorController.send(completion: .finished)
        connector.dispose()
    }
}
