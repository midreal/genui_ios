import Foundation

/// A message in the chat conversation history.
///
/// Matches Dart's sealed `ChatMessage` hierarchy. Each variant carries
/// typed parts for multi-modal content.
public enum ChatMessage {
    /// An internal/system message not shown to the user.
    case `internal`(text: String)
    /// A user-sent message containing one or more parts.
    case user(parts: [MessagePart])
    /// A user UI interaction event (button click, form submit, etc.).
    case userUiInteraction(parts: [MessagePart])
    /// An AI text response containing one or more parts.
    case aiText(parts: [MessagePart])
    /// A tool response containing results.
    case toolResponse(results: [MessagePart])
    /// An AI-generated UI surface.
    case aiUi(surfaceId: String, definition: SurfaceDefinition)

    // MARK: - Convenience Factories

    /// Creates a user message with a single text part.
    public static func userText(_ text: String) -> ChatMessage {
        .user(parts: [.text(text)])
    }

    /// Creates an AI text message with a single text part.
    public static func aiTextMessage(_ text: String) -> ChatMessage {
        .aiText(parts: [.text(text)])
    }

    /// Creates a user UI interaction with a single text part.
    public static func userInteractionText(_ text: String) -> ChatMessage {
        .userUiInteraction(parts: [.text(text)])
    }

    // MARK: - Computed Properties

    /// The combined text content from all text parts, or `nil` for non-text messages.
    public var text: String? {
        switch self {
        case .internal(let t):
            return t
        case .user(let parts), .userUiInteraction(let parts), .aiText(let parts):
            let texts = parts.compactMap { $0.text }
            return texts.isEmpty ? nil : texts.joined(separator: "\n")
        case .toolResponse:
            return nil
        case .aiUi:
            return nil
        }
    }

    /// Whether this message was sent by the user.
    public var isUser: Bool {
        switch self {
        case .user, .userUiInteraction: return true
        default: return false
        }
    }

    /// Whether this is a UI surface message.
    public var isUiSurface: Bool {
        if case .aiUi = self { return true }
        return false
    }

    /// The surface ID for `.aiUi` messages, `nil` otherwise.
    public var surfaceId: String? {
        if case .aiUi(let sid, _) = self { return sid }
        return nil
    }
}
