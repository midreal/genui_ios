import Foundation

/// Parses raw SSE text lines into JSON-RPC result dictionaries.
///
/// Handles `data:` lines, comments (`:`), and event boundaries (empty lines).
/// Extracts `result` from JSON-RPC 2.0 envelope, throwing `A2AException` on errors.
public final class SseParser {
    private var dataLines: [String] = []

    public init() {}

    /// Processes a single SSE line. Returns a parsed JSON result when an event boundary is reached.
    /// Strips trailing `\r` for compatibility with `\r\n` line endings.
    public func processLine(_ rawLine: String) throws -> JsonMap? {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

        if line.hasPrefix("data:") {
            let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if !data.isEmpty {
                // If this data line is itself a complete JSON object and we already have
                // accumulated lines, flush the previous event first (handles servers that
                // omit the blank-line separator between consecutive events).
                if !dataLines.isEmpty, data.hasPrefix("{") {
                    let previous = dataLines.joined(separator: "\n")
                    dataLines.removeAll()
                    if let result = try parseJSONRPC(previous) {
                        dataLines.append(data)
                        return result
                    }
                }
                dataLines.append(data)
            }
            return nil
        }

        if line.hasPrefix(":") {
            return nil
        }

        if line.isEmpty {
            guard !dataLines.isEmpty else { return nil }
            let joined = dataLines.joined(separator: "\n")
            dataLines.removeAll()
            return try parseJSONRPC(joined)
        }

        return nil
    }

    private func parseJSONRPC(_ text: String) throws -> JsonMap? {
        guard let jsonData = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? JsonMap else {
            // Not valid JSON — could be a partial line or non-JSON data; skip silently.
            return nil
        }

        if let result = json["result"] as? JsonMap {
            return result
        }
        if let error = json["error"] as? JsonMap {
            throw A2AException.fromJSONRPCError(error)
        }
        // result: null or unrecognised envelope — skip
        return nil
    }

    /// Resets accumulated data lines.
    public func reset() {
        dataLines.removeAll()
    }

    /// Flushes any remaining buffered data as a final event.
    public func flush() throws -> JsonMap? {
        guard !dataLines.isEmpty else { return nil }
        let result = try processLine("")
        return result
    }
}
