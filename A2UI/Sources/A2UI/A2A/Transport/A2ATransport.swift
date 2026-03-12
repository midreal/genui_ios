import Foundation

/// Generic transport protocol for A2A client-server communication.
///
/// Matches Dart's `Transport` abstract class. Implementations handle
/// different protocols (HTTP, SSE, WebSocket, etc.).
public protocol A2ATransport {
    /// Additional headers sent with every request.
    var authHeaders: [String: String] { get }

    /// Fetches a resource from the server via HTTP GET.
    func get(path: String, headers: [String: String]) async throws -> JsonMap

    /// Sends a single JSON-RPC request, expecting a single response.
    func send(_ request: JsonMap, path: String, headers: [String: String]) async throws -> JsonMap

    /// Sends a JSON-RPC request and returns a stream of response events.
    func sendStream(_ request: JsonMap, headers: [String: String]) -> AsyncThrowingStream<JsonMap, Error>

    /// Releases underlying resources.
    func close()
}

extension A2ATransport {
    public func get(path: String) async throws -> JsonMap {
        try await get(path: path, headers: [:])
    }

    public func send(_ request: JsonMap) async throws -> JsonMap {
        try await send(request, path: "", headers: [:])
    }

    public func sendStream(_ request: JsonMap) -> AsyncThrowingStream<JsonMap, Error> {
        sendStream(request, headers: [:])
    }
}
