import Foundation

/// SSE-capable transport that extends `HttpTransport` with streaming support.
///
/// Matches Dart's `SseTransport`. Overrides `sendStream` to POST with
/// `Accept: text/event-stream` and parse the SSE response using `SseParser`.
public final class A2ASseTransport: HttpTransport {

    public override func sendStream(
        _ request: JsonMap,
        headers: [String: String] = [:]
    ) -> AsyncThrowingStream<JsonMap, Error> {
        AsyncThrowingStream { [url, authHeaders, urlSession] continuation in
            let task = Task {
                guard let serverURL = URL(string: url) else {
                    continuation.finish(throwing: A2AException.network(message: "Invalid URL: \(url)"))
                    return
                }

                guard let bodyData = try? JSONSerialization.data(withJSONObject: request) else {
                    continuation.finish(throwing: A2AException.parsing(message: "Failed to serialize request body"))
                    return
                }

                var urlRequest = URLRequest(url: serverURL)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                for (k, v) in authHeaders { urlRequest.setValue(v, forHTTPHeaderField: k) }
                for (k, v) in headers { urlRequest.setValue(v, forHTTPHeaderField: k) }
                urlRequest.httpBody = bodyData

                do {
                    let (bytes, response) = try await urlSession.bytes(for: urlRequest)

                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        continuation.finish(throwing: A2AException.http(
                            statusCode: http.statusCode,
                            reason: HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                        ))
                        return
                    }

                    let parser = SseParser()
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let result = try parser.processLine(line) {
                            continuation.yield(result)
                        }
                    }

                    if let result = try parser.flush() {
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch let error as A2AException {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: A2AException.network(message: "SSE stream error: \(error)"))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Legacy SseTransport (Combine-based, used by A2uiAgentConnector)

/// Combine-based SSE transport that emits parsed A2UI messages and text.
///
/// This is the legacy transport used by `A2uiAgentConnector` for backward compatibility.
/// New code should prefer `A2AClient` + `A2ASseTransport`.
public final class SseTransport: A2UITransport {

    private let serverURL: URL
    private let authHeaders: [String: String]

    private let messagesSubject = PassthroughSubject<A2UIMessage, Never>()
    private let textSubject = PassthroughSubject<String, Never>()

    var onEvent: (((taskId: String, contextId: String)) -> Void)?

    private var streamTask: Task<Void, Never>?

    public var incomingMessages: AnyPublisher<A2UIMessage, Never> {
        messagesSubject.eraseToAnyPublisher()
    }

    public var incomingText: AnyPublisher<String, Never> {
        textSubject.eraseToAnyPublisher()
    }

    public init(url: URL, authHeaders: [String: String] = [:]) {
        self.serverURL = url
        self.authHeaders = authHeaders
    }

    // MARK: - Send User Action

    public func sendAction(_ event: UserActionEvent) async throws {
        let dataPart: JsonMap = ["kind": "data", "data": event.toJSON()]
        let message: JsonMap = [
            "kind": "message",
            "messageId": UUID().uuidString,
            "role": "user",
            "parts": [dataPart]
        ]
        let rpcBody: JsonMap = [
            "jsonrpc": "2.0",
            "method": "message/send",
            "params": ["message": message] as JsonMap,
            "id": Int.random(in: 1...Int.max)
        ]
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in authHeaders { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = try JSONSerialization.data(withJSONObject: rpcBody)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw A2AException.http(statusCode: http.statusCode, reason: "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Open SSE Stream

    func openStream(body: JsonMap) {
        cancelStream()

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            NSLog("[SseTransport] Failed to serialize request body")
            return
        }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        for (k, v) in authHeaders { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = bodyData

        streamTask = Task { [weak self] in
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                    NSLog("[SseTransport] HTTP error: \(http.statusCode)")
                    return
                }

                let parser = SseParser()
                for try await line in bytes.lines {
                    guard !Task.isCancelled else { break }
                    do {
                        if let result = try parser.processLine(line) {
                            self?.handleEvent(result)
                        }
                    } catch {
                        NSLog("[SseTransport] Parse error: \(error)")
                    }
                }

                if let result = try? parser.flush() {
                    self?.handleEvent(result)
                }
            } catch {
                if !Task.isCancelled {
                    NSLog("[SseTransport] Stream error: \(error)")
                }
            }
        }
    }

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
    }

    public func dispose() {
        cancelStream()
        messagesSubject.send(completion: .finished)
        textSubject.send(completion: .finished)
    }

    // MARK: - Event Handling

    private func handleEvent(_ json: JsonMap) {
        guard let event = A2AEvent.fromJSON(json) else { return }

        onEvent?((taskId: event.taskId, contextId: event.contextId))

        let status: A2ATaskStatus
        switch event {
        case .statusUpdate(_, _, let s, _): status = s
        case .taskStatusUpdate(_, _, let s, _): status = s
        case .artifactUpdate: return
        }

        if status.state.isError {
            let errorText = "A2A Error: \(status.state.rawValue)"
            DispatchQueue.main.async { [weak self] in
                self?.textSubject.send(errorText)
            }
            return
        }

        guard let message = status.message else { return }

        for part in message.parts {
            switch part {
            case .data(let data, _):
                if let a2uiMsg = try? A2UIMessage.fromJSON(data) {
                    DispatchQueue.main.async { [weak self] in
                        self?.messagesSubject.send(a2uiMsg)
                    }
                }
            case .text(let text, _):
                DispatchQueue.main.async { [weak self] in
                    self?.textSubject.send(text)
                }
            default:
                break
            }
        }
    }
}
