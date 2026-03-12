import Foundation

/// A client for interacting with an A2A (Agent-to-Agent) server.
///
/// Provides methods for all JSON-RPC calls defined in the A2A specification.
/// Matches Dart's `A2AClient`.
public final class A2AClient {

    /// The base URL of the A2A server.
    public let url: String

    private let transport: A2ATransport
    private var requestId: Int = 0

    /// The well-known path for the agent card.
    public static let agentCardPath = "/.well-known/agent-card.json"

    /// Creates an `A2AClient` with an explicit transport.
    public init(url: String, transport: A2ATransport) {
        self.url = url
        self.transport = transport
    }

    /// Creates an `A2AClient` with default SSE transport.
    public convenience init(url: String, authHeaders: [String: String] = [:]) {
        let transport = A2ASseTransport(url: url, authHeaders: authHeaders)
        self.init(url: url, transport: transport)
    }

    // MARK: - Agent Card

    /// Fetches the public agent card from `/.well-known/agent-card.json`.
    public func getAgentCard() async throws -> AgentCard {
        let json = try await transport.get(path: Self.agentCardPath)
        guard let card = AgentCard.fromJSON(json) else {
            throw A2AException.parsing(message: "Failed to parse AgentCard")
        }
        return card
    }

    /// Fetches the authenticated extended agent card.
    public func getAuthenticatedExtendedCard(token: String) async throws -> AgentCard {
        let json = try await transport.get(
            path: Self.agentCardPath,
            headers: ["Authorization": "Bearer \(token)"]
        )
        guard let card = AgentCard.fromJSON(json) else {
            throw A2AException.parsing(message: "Failed to parse AgentCard")
        }
        return card
    }

    // MARK: - message/send

    /// Sends a message for a single-shot interaction via `message/send`.
    public func messageSend(_ message: A2AMessage) async throws -> A2ATask {
        var params: JsonMap = ["message": message.toJSON()]
        if let extensions = message.extensions {
            params["extensions"] = extensions
        }
        let rpc = buildRPC(method: "message/send", params: params)

        var headers = [String: String]()
        if let extensions = message.extensions {
            headers["X-A2A-Extensions"] = extensions.joined(separator: ",")
        }

        let response = try await transport.send(rpc, path: "", headers: headers)
        if let error = response["error"] as? JsonMap {
            throw A2AException.fromJSONRPCError(error)
        }
        guard let result = response["result"] as? JsonMap,
              let task = A2ATask.fromJSON(result) else {
            throw A2AException.parsing(message: "Failed to parse Task from message/send response")
        }
        return task
    }

    // MARK: - message/stream

    /// Sends a message and subscribes to real-time updates via `message/stream`.
    /// Returns an `AsyncThrowingStream` of `A2AEvent`.
    public func messageStream(_ message: A2AMessage) -> AsyncThrowingStream<A2AEvent, Error> {
        var params: JsonMap = [
            "configuration": NSNull(),
            "metadata": NSNull(),
            "message": message.toJSON()
        ]
        if let extensions = message.extensions {
            params["extensions"] = extensions
        }
        let rpc = buildRPC(method: "message/stream", params: params)

        var headers = [String: String]()
        if let extensions = message.extensions {
            headers["X-A2A-Extensions"] = extensions.joined(separator: ",")
        }

        let rawStream = transport.sendStream(rpc, headers: headers)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await data in rawStream {
                        if Task.isCancelled { break }

                        if let error = data["error"] as? JsonMap {
                            continuation.finish(throwing: A2AException.fromJSONRPCError(error))
                            return
                        }

                        if data["kind"] != nil {
                            if let kind = data["kind"] as? String, kind == "task" {
                                if let task = A2ATask.fromJSON(data) {
                                    continuation.yield(.statusUpdate(
                                        taskId: task.id,
                                        contextId: task.contextId,
                                        status: task.status,
                                        isFinal: false
                                    ))
                                }
                            } else if let event = A2AEvent.fromJSON(data) {
                                continuation.yield(event)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - tasks/get

    /// Retrieves the current state of a task.
    public func getTask(_ taskId: String) async throws -> A2ATask {
        let rpc = buildRPC(method: "tasks/get", params: ["id": taskId])
        let response = try await transport.send(rpc)
        if let error = response["error"] as? JsonMap {
            throw A2AException.fromJSONRPCError(error)
        }
        guard let result = response["result"] as? JsonMap,
              let task = A2ATask.fromJSON(result) else {
            throw A2AException.parsing(message: "Failed to parse Task from tasks/get response")
        }
        return task
    }

    // MARK: - tasks/list

    /// Retrieves a list of tasks.
    public func listTasks(_ params: ListTasksParams? = nil) async throws -> ListTasksResult {
        let rpc = buildRPC(method: "tasks/list", params: params?.toJSON() ?? [:])
        let response = try await transport.send(rpc)
        if let error = response["error"] as? JsonMap {
            throw A2AException.fromJSONRPCError(error)
        }
        guard let result = response["result"] as? JsonMap,
              let listResult = ListTasksResult.fromJSON(result) else {
            throw A2AException.parsing(message: "Failed to parse ListTasksResult")
        }
        return listResult
    }

    // MARK: - tasks/cancel

    /// Requests the cancellation of an ongoing task.
    public func cancelTask(_ taskId: String) async throws -> A2ATask {
        let rpc = buildRPC(method: "tasks/cancel", params: ["id": taskId])
        let response = try await transport.send(rpc)
        if let error = response["error"] as? JsonMap {
            throw A2AException.fromJSONRPCError(error)
        }
        guard let result = response["result"] as? JsonMap,
              let task = A2ATask.fromJSON(result) else {
            throw A2AException.parsing(message: "Failed to parse Task from tasks/cancel response")
        }
        return task
    }

    // MARK: - tasks/resubscribe

    /// Resubscribes to an SSE stream for an ongoing task.
    public func resubscribeToTask(_ taskId: String) -> AsyncThrowingStream<A2AEvent, Error> {
        let rpc = buildRPC(method: "tasks/resubscribe", params: ["id": taskId])
        let rawStream = transport.sendStream(rpc)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await data in rawStream {
                        if Task.isCancelled { break }
                        if let error = data["error"] as? JsonMap {
                            continuation.finish(throwing: A2AException.fromJSONRPCError(error))
                            return
                        }
                        if let event = A2AEvent.fromJSON(data) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Push Notification Config

    /// Sets or updates the push notification configuration for a task.
    public func setPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        let rpc = buildRPC(method: "tasks/pushNotificationConfig/set", params: config.toJSON())
        let response = try await transport.send(rpc)
        if let error = response["error"] as? JsonMap {
            throw A2AException.fromJSONRPCError(error)
        }
        guard let result = response["result"] as? JsonMap,
              let parsed = TaskPushNotificationConfig.fromJSON(result) else {
            throw A2AException.parsing(message: "Failed to parse TaskPushNotificationConfig")
        }
        return parsed
    }

    /// Retrieves a specific push notification configuration.
    public func getPushNotificationConfig(taskId: String, configId: String) async throws -> TaskPushNotificationConfig {
        let rpc = buildRPC(method: "tasks/pushNotificationConfig/get", params: [
            "id": taskId,
            "pushNotificationConfigId": configId
        ])
        let response = try await transport.send(rpc)
        if let error = response["error"] as? JsonMap {
            throw A2AException.fromJSONRPCError(error)
        }
        guard let result = response["result"] as? JsonMap,
              let parsed = TaskPushNotificationConfig.fromJSON(result) else {
            throw A2AException.parsing(message: "Failed to parse TaskPushNotificationConfig")
        }
        return parsed
    }

    /// Lists all push notification configurations for a task.
    public func listPushNotificationConfigs(taskId: String) async throws -> [PushNotificationConfig] {
        let rpc = buildRPC(method: "tasks/pushNotificationConfig/list", params: ["id": taskId])
        let response = try await transport.send(rpc)
        if let error = response["error"] as? JsonMap {
            throw A2AException.fromJSONRPCError(error)
        }
        guard let result = response["result"] as? JsonMap,
              let configs = result["configs"] as? [JsonMap] else {
            throw A2AException.parsing(message: "Failed to parse push notification configs")
        }
        return configs.compactMap { PushNotificationConfig.fromJSON($0) }
    }

    /// Deletes a specific push notification configuration.
    public func deletePushNotificationConfig(taskId: String, configId: String) async throws {
        let rpc = buildRPC(method: "tasks/pushNotificationConfig/delete", params: [
            "id": taskId,
            "pushNotificationConfigId": configId
        ])
        let response = try await transport.send(rpc)
        if let error = response["error"] as? JsonMap {
            throw A2AException.fromJSONRPCError(error)
        }
    }

    // MARK: - Close

    /// Closes the underlying transport connection.
    public func close() {
        transport.close()
    }

    // MARK: - Private

    private func buildRPC(method: String, params: JsonMap) -> JsonMap {
        requestId += 1
        return [
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": requestId
        ]
    }
}
