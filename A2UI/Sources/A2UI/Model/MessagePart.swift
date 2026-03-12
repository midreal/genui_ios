import Foundation

/// A part of a multi-modal message.
///
/// Matches Dart's sealed `MessagePart` hierarchy.
public enum MessagePart {
    /// Plain text content.
    case text(String)
    /// Structured data (JSON dictionary).
    case data(JsonMap?)
    /// Image content from bytes, base64, or URL.
    case image(ImageContent)
    /// A request from the model to call a tool.
    case toolCall(id: String, toolName: String, arguments: JsonMap)
    /// The result of a tool call.
    case toolResult(callId: String, result: String)
    /// A provider-specific "thinking" block.
    case thinking(String)

    /// Extracts text content, returning `nil` for non-text parts.
    public var text: String? {
        if case .text(let t) = self { return t }
        if case .thinking(let t) = self { return t }
        return nil
    }
}

/// Image content for an `ImagePart`, supporting multiple source types.
public struct ImageContent {
    public let bytes: Data?
    public let base64: String?
    public let url: URL?
    public let mimeType: String

    public static func fromBytes(_ bytes: Data, mimeType: String) -> ImageContent {
        ImageContent(bytes: bytes, base64: nil, url: nil, mimeType: mimeType)
    }

    public static func fromBase64(_ base64: String, mimeType: String) -> ImageContent {
        ImageContent(bytes: nil, base64: base64, url: nil, mimeType: mimeType)
    }

    public static func fromURL(_ url: URL, mimeType: String) -> ImageContent {
        ImageContent(bytes: nil, base64: nil, url: url, mimeType: mimeType)
    }
}
