import Foundation

/// Extracts A2UI JSON blocks from a streaming text input.
///
/// Handles two formats:
/// 1. Markdown JSON fences: ` ```json ... ``` `
/// 2. Balanced-brace JSON: `{ ... }` with proper string/escape tracking.
public final class A2UIStreamParser {

    private var buffer = ""

    public init() {}

    /// Feeds a text chunk into the parser and returns any complete A2UI messages found.
    public func addChunk(_ chunk: String) -> [A2UIMessage] {
        buffer += chunk
        buffer = buffer.replacingOccurrences(of: "<a2ui_message>", with: "")
        buffer = buffer.replacingOccurrences(of: "</a2ui_message>", with: "")

        var messages = [A2UIMessage]()
        var didExtract = true

        while didExtract {
            didExtract = false

            // Try markdown json fence
            if let range = extractMarkdownJSON() {
                let jsonStr = String(buffer[range])
                buffer.removeSubrange(range)
                if let msg = parseJSON(jsonStr) {
                    messages.append(msg)
                    didExtract = true
                    continue
                }
            }

            // Try balanced braces
            if let range = extractBalancedBraces() {
                let jsonStr = String(buffer[range])
                buffer.removeSubrange(range)
                if let msg = parseJSON(jsonStr) {
                    messages.append(msg)
                    didExtract = true
                    continue
                }
            }
        }

        return messages
    }

    /// Returns any remaining non-JSON text in the buffer (for chat display).
    public var remainingText: String {
        buffer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resets the parser state.
    public func reset() {
        buffer = ""
    }

    // MARK: - Extraction

    private func extractMarkdownJSON() -> Range<String.Index>? {
        guard let startMarker = buffer.range(of: "```json") else { return nil }
        let searchStart = startMarker.upperBound
        guard let endMarker = buffer.range(of: "```", range: searchStart..<buffer.endIndex) else {
            return nil
        }
        let jsonContent = buffer[searchStart..<endMarker.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonContent.isEmpty { return nil }

        return startMarker.lowerBound..<endMarker.upperBound
    }

    private func extractBalancedBraces() -> Range<String.Index>? {
        guard let openIdx = buffer.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escape = false
        var idx = openIdx

        while idx < buffer.endIndex {
            let char = buffer[idx]

            if escape {
                escape = false
                idx = buffer.index(after: idx)
                continue
            }

            if char == "\\" && inString {
                escape = true
                idx = buffer.index(after: idx)
                continue
            }

            if char == "\"" {
                inString.toggle()
                idx = buffer.index(after: idx)
                continue
            }

            if !inString {
                if char == "{" { depth += 1 }
                else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        let endIdx = buffer.index(after: idx)
                        return openIdx..<endIdx
                    }
                }
            }

            idx = buffer.index(after: idx)
        }

        return nil
    }

    private func parseJSON(_ jsonString: String) -> A2UIMessage? {
        let cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? JsonMap else {
            return nil
        }
        return try? A2UIMessage.fromJSON(json)
    }
}
