import Foundation
import Combine

/// The state of a conversation session.
public struct ConversationState {
    /// IDs of currently active surfaces.
    public var surfaces: [String]
    /// The most recently received text content.
    public var latestText: String
    /// Whether the conversation is waiting for a response.
    public var isWaiting: Bool

    public init(surfaces: [String] = [], latestText: String = "", isWaiting: Bool = false) {
        self.surfaces = surfaces
        self.latestText = latestText
        self.isWaiting = isWaiting
    }
}

/// Events emitted by a conversation session.
public enum ConversationEvent {
    case surfaceAdded(surfaceId: String, definition: SurfaceDefinition)
    case componentsUpdated(surfaceId: String, definition: SurfaceDefinition)
    case surfaceRemoved(surfaceId: String)
    case contentReceived(text: String)
    case waiting
    case error(Error)
}

/// High-level facade that connects a `Transport` to a `SurfaceController`.
///
/// Manages the four-way wiring:
/// 1. Transport incoming messages → Controller
/// 2. Transport incoming text → events
/// 3. Controller surface updates → events + state
/// 4. Controller onSubmit → Transport
public final class Conversation {

    /// The underlying surface controller.
    public let controller: SurfaceController

    /// The transport layer.
    public let transport: A2UITransport

    private let stateSubject: CurrentValueSubject<ConversationState, Never>
    private let eventsSubject = PassthroughSubject<ConversationEvent, Never>()
    private var cancellables = Set<AnyCancellable>()

    /// The current conversation state.
    public var state: AnyPublisher<ConversationState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    /// Stream of conversation events.
    public var events: AnyPublisher<ConversationEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }

    /// The current state value.
    public var currentState: ConversationState {
        stateSubject.value
    }

    public init(controller: SurfaceController, transport: A2UITransport) {
        self.controller = controller
        self.transport = transport
        self.stateSubject = CurrentValueSubject(ConversationState())
        wireUp()
    }

    private func wireUp() {
        // 1. Transport messages → Controller
        transport.incomingMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.controller.handleMessage(message)
            }
            .store(in: &cancellables)

        // 2. Transport text → events
        transport.incomingText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.stateSubject.value.latestText = text
                self?.eventsSubject.send(.contentReceived(text: text))
            }
            .store(in: &cancellables)

        // 3. Controller surface updates → events + state
        controller.surfaceUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self = self else { return }
                switch update {
                case .surfaceAdded(let id, let def):
                    if !self.stateSubject.value.surfaces.contains(id) {
                        self.stateSubject.value.surfaces.append(id)
                    }
                    self.eventsSubject.send(.surfaceAdded(surfaceId: id, definition: def))

                case .componentsUpdated(let id, let def):
                    self.eventsSubject.send(.componentsUpdated(surfaceId: id, definition: def))

                case .surfaceRemoved(let id):
                    self.stateSubject.value.surfaces.removeAll { $0 == id }
                    self.eventsSubject.send(.surfaceRemoved(surfaceId: id))
                }
            }
            .store(in: &cancellables)

        // 4. Controller onSubmit → Transport
        controller.onSubmit
            .sink { [weak self] event in
                Task { [weak self] in
                    try? await self?.transport.sendAction(event)
                }
            }
            .store(in: &cancellables)
    }

    /// Disposes of all resources.
    public func dispose() {
        cancellables.removeAll()
        controller.dispose()
        transport.dispose()
    }
}
