import Foundation

/// Non-streaming HTTP transport for A2A JSON-RPC communication.
///
/// Matches Dart's `HttpTransport`. Supports `get` and `send` but
/// throws on `sendStream` (use `A2ASseTransport` for streaming).
public class HttpTransport: A2ATransport {
    public let url: String
    public let authHeaders: [String: String]
    let urlSession: URLSession

    public init(url: String, authHeaders: [String: String] = [:], urlSession: URLSession = .shared) {
        self.url = url
        self.authHeaders = authHeaders
        self.urlSession = urlSession
    }

    public func get(path: String, headers: [String: String] = [:]) async throws -> JsonMap {
        guard let requestURL = URL(string: path, relativeTo: URL(string: url)) else {
            throw A2AException.network(message: "Invalid URL: \(url)\(path)")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (k, v) in authHeaders { request.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }

        let (data, response) = try await urlSession.data(for: request)
        try checkHTTPStatus(response)
        return try parseJSON(data)
    }

    public func send(_ request: JsonMap, path: String = "", headers: [String: String] = [:]) async throws -> JsonMap {
        let targetURL: URL
        if path.isEmpty {
            guard let u = URL(string: url) else {
                throw A2AException.network(message: "Invalid URL: \(url)")
            }
            targetURL = u
        } else {
            guard let u = URL(string: path, relativeTo: URL(string: url)) else {
                throw A2AException.network(message: "Invalid URL: \(url)\(path)")
            }
            targetURL = u
        }

        var urlRequest = URLRequest(url: targetURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in authHeaders { urlRequest.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in headers { urlRequest.setValue(v, forHTTPHeaderField: k) }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request)

        let (data, response) = try await urlSession.data(for: urlRequest)
        try checkHTTPStatus(response)
        return try parseJSON(data)
    }

    public func sendStream(_ request: JsonMap, headers: [String: String] = [:]) -> AsyncThrowingStream<JsonMap, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: A2AException.unsupportedOperation(
                message: "HttpTransport does not support streaming. Use A2ASseTransport."
            ))
        }
    }

    public func close() {}

    func checkHTTPStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode >= 400 {
            throw A2AException.http(statusCode: http.statusCode, reason: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }

    func parseJSON(_ data: Data) throws -> JsonMap {
        guard let json = try JSONSerialization.jsonObject(with: data) as? JsonMap else {
            throw A2AException.parsing(message: "Response is not a JSON object")
        }
        return json
    }
}
