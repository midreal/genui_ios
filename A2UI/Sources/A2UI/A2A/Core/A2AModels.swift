import Foundation

// MARK: - A2A 协议数据模型
//
// A2A（Agent-to-Agent）协议数据模型的 Swift 实现，
// 对应 Dart genui_a2ui 包中的核心模型。

// MARK: - AgentCard

/// A2A Agent 的自描述清单。
public struct AgentCard {
    public let protocolVersion: String
    public let name: String
    public let description: String
    public let url: String
    public let capabilities: AgentCapabilities
    public let preferredTransport: AgentInterface?
    public let additionalInterfaces: [AgentInterface]?
    public let iconUrl: String?
    public let provider: AgentProvider?
    public let version: String?
    public let documentationUrl: String?
    public let securitySchemes: [String: SecurityScheme]?
    public let security: [[String: [String]]]?
    public let defaultInputModes: [String]?
    public let defaultOutputModes: [String]?
    public let skills: [AgentSkill]?
    public let supportsAuthenticatedExtendedCard: Bool

    public init(
        protocolVersion: String,
        name: String,
        description: String,
        url: String,
        capabilities: AgentCapabilities = AgentCapabilities(),
        preferredTransport: AgentInterface? = nil,
        additionalInterfaces: [AgentInterface]? = nil,
        iconUrl: String? = nil,
        provider: AgentProvider? = nil,
        version: String? = nil,
        documentationUrl: String? = nil,
        securitySchemes: [String: SecurityScheme]? = nil,
        security: [[String: [String]]]? = nil,
        defaultInputModes: [String]? = nil,
        defaultOutputModes: [String]? = nil,
        skills: [AgentSkill]? = nil,
        supportsAuthenticatedExtendedCard: Bool = false
    ) {
        self.protocolVersion = protocolVersion
        self.name = name
        self.description = description
        self.url = url
        self.capabilities = capabilities
        self.preferredTransport = preferredTransport
        self.additionalInterfaces = additionalInterfaces
        self.iconUrl = iconUrl
        self.provider = provider
        self.version = version
        self.documentationUrl = documentationUrl
        self.securitySchemes = securitySchemes
        self.security = security
        self.defaultInputModes = defaultInputModes
        self.defaultOutputModes = defaultOutputModes
        self.skills = skills
        self.supportsAuthenticatedExtendedCard = supportsAuthenticatedExtendedCard
    }

    public static func fromJSON(_ json: JsonMap) -> AgentCard? {
        guard let name = json["name"] as? String,
              let description = json["description"] as? String,
              let url = json["url"] as? String else { return nil }
        let protocolVersion = json["protocolVersion"] as? String ?? ""
        let capJson = json["capabilities"] as? JsonMap ?? [:]

        var preferredTransport: AgentInterface? = nil
        if let ptJson = json["preferredTransport"] as? JsonMap {
            preferredTransport = AgentInterface.fromJSON(ptJson)
        }

        var additionalInterfaces: [AgentInterface]? = nil
        if let aiArr = json["additionalInterfaces"] as? [JsonMap] {
            additionalInterfaces = aiArr.compactMap { AgentInterface.fromJSON($0) }
        }

        var providerObj: AgentProvider? = nil
        if let pJson = json["provider"] as? JsonMap {
            providerObj = AgentProvider.fromJSON(pJson)
        }

        var securitySchemesMap: [String: SecurityScheme]? = nil
        if let ssJson = json["securitySchemes"] as? [String: JsonMap] {
            var built = [String: SecurityScheme]()
            for (key, val) in ssJson {
                if let scheme = SecurityScheme.fromJSON(val) { built[key] = scheme }
            }
            if !built.isEmpty { securitySchemesMap = built }
        }

        var skillsList: [AgentSkill]? = nil
        if let sArr = json["skills"] as? [JsonMap] {
            skillsList = sArr.compactMap { AgentSkill.fromJSON($0) }
        }

        return AgentCard(
            protocolVersion: protocolVersion,
            name: name,
            description: description,
            url: url,
            capabilities: AgentCapabilities.fromJSON(capJson),
            preferredTransport: preferredTransport,
            additionalInterfaces: additionalInterfaces,
            iconUrl: json["iconUrl"] as? String,
            provider: providerObj,
            version: json["version"] as? String,
            documentationUrl: json["documentationUrl"] as? String,
            securitySchemes: securitySchemesMap,
            security: json["security"] as? [[String: [String]]],
            defaultInputModes: json["defaultInputModes"] as? [String],
            defaultOutputModes: json["defaultOutputModes"] as? [String],
            skills: skillsList,
            supportsAuthenticatedExtendedCard: json["supportsAuthenticatedExtendedCard"] as? Bool ?? false
        )
    }
}

public struct AgentCapabilities {
    public let streaming: Bool
    public let pushNotifications: Bool
    public let stateTransitionHistory: Bool
    public let extensions: [AgentExtension]?

    public init(
        streaming: Bool = false,
        pushNotifications: Bool = false,
        stateTransitionHistory: Bool = false,
        extensions: [AgentExtension]? = nil
    ) {
        self.streaming = streaming
        self.pushNotifications = pushNotifications
        self.stateTransitionHistory = stateTransitionHistory
        self.extensions = extensions
    }

    public static func fromJSON(_ json: JsonMap) -> AgentCapabilities {
        var exts: [AgentExtension]? = nil
        if let extArr = json["extensions"] as? [JsonMap] {
            exts = extArr.compactMap { AgentExtension.fromJSON($0) }
        }
        return AgentCapabilities(
            streaming: json["streaming"] as? Bool ?? false,
            pushNotifications: json["pushNotifications"] as? Bool ?? false,
            stateTransitionHistory: json["stateTransitionHistory"] as? Bool ?? false,
            extensions: exts
        )
    }
}

// MARK: - Message

/// A2A 消息的发送方角色。
public enum A2ARole: String {
    case user = "user"
    case agent = "agent"
}

/// A2A 交互中的单条通信消息。
public struct A2AMessage {
    public let messageId: String
    public let role: A2ARole
    public let parts: [A2APart]
    public let taskId: String?
    public let contextId: String?
    public let referenceTaskIds: [String]?
    public let extensions: [String]?
    public let metadata: JsonMap?
    public let kind: String

    public init(
        messageId: String = UUID().uuidString,
        role: A2ARole,
        parts: [A2APart],
        taskId: String? = nil,
        contextId: String? = nil,
        referenceTaskIds: [String]? = nil,
        extensions: [String]? = nil,
        metadata: JsonMap? = nil
    ) {
        self.messageId = messageId
        self.role = role
        self.parts = parts
        self.taskId = taskId
        self.contextId = contextId
        self.referenceTaskIds = referenceTaskIds
        self.extensions = extensions
        self.metadata = metadata
        self.kind = "message"
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = [
            "kind": kind,
            "messageId": messageId,
            "role": role.rawValue,
            "parts": parts.map { $0.toJSON() }
        ]
        if let taskId { json["taskId"] = taskId }
        if let contextId { json["contextId"] = contextId }
        if let referenceTaskIds { json["referenceTaskIds"] = referenceTaskIds }
        if let extensions { json["extensions"] = extensions }
        if let metadata { json["metadata"] = metadata }
        return json
    }

    public func withUpdated(
        referenceTaskIds: [String]? = nil,
        contextId: String? = nil,
        metadata: JsonMap? = nil
    ) -> A2AMessage {
        A2AMessage(
            messageId: self.messageId,
            role: self.role,
            parts: self.parts,
            taskId: self.taskId,
            contextId: contextId ?? self.contextId,
            referenceTaskIds: referenceTaskIds ?? self.referenceTaskIds,
            extensions: self.extensions,
            metadata: metadata ?? self.metadata
        )
    }
}

// MARK: - Part

/// 消息中的一个内容片段。
public enum A2APart {
    case text(String, metadata: JsonMap? = nil)
    case data(JsonMap, metadata: JsonMap? = nil)
    case file(A2AFileContent, metadata: JsonMap? = nil)

    public func toJSON() -> JsonMap {
        switch self {
        case .text(let text, let metadata):
            var json: JsonMap = ["kind": "text", "text": text]
            if let metadata { json["metadata"] = metadata }
            return json
        case .data(let data, let metadata):
            var json: JsonMap = ["kind": "data", "data": data]
            if let metadata { json["metadata"] = metadata }
            return json
        case .file(let file, let metadata):
            var json: JsonMap = ["kind": "file", "file": file.toJSON()]
            if let metadata { json["metadata"] = metadata }
            return json
        }
    }

    public static func fromJSON(_ json: JsonMap) -> A2APart? {
        let kind = json["kind"] as? String ?? ""
        let metadata = json["metadata"] as? JsonMap
        switch kind {
        case "text":
            guard let text = json["text"] as? String else { return nil }
            return .text(text, metadata: metadata)
        case "data":
            guard let data = json["data"] as? JsonMap else { return nil }
            return .data(data, metadata: metadata)
        case "file":
            guard let fileJson = json["file"] as? JsonMap,
                  let file = A2AFileContent.fromJSON(fileJson) else { return nil }
            return .file(file, metadata: metadata)
        default:
            return nil
        }
    }
}

public struct A2AFileContent {
    public let uri: String?
    public let bytes: String?
    public let mimeType: String?

    public func toJSON() -> JsonMap {
        var json: JsonMap = [:]
        if let uri { json["uri"] = uri }
        if let bytes { json["bytes"] = bytes }
        if let mimeType { json["mimeType"] = mimeType }
        return json
    }

    public static func fromJSON(_ json: JsonMap) -> A2AFileContent? {
        A2AFileContent(
            uri: json["uri"] as? String,
            bytes: json["bytes"] as? String,
            mimeType: json["mimeType"] as? String
        )
    }
}

// MARK: - Task

/// A2A 任务，表示一次有状态的操作或对话。
public struct A2ATask {
    public let id: String
    public let contextId: String
    public let status: A2ATaskStatus
    public let history: [A2AMessage]?
    public let artifacts: [A2AArtifact]?
    public let metadata: JsonMap?
    public let lastUpdated: Int?
    public let kind: String

    public init(
        id: String,
        contextId: String,
        status: A2ATaskStatus,
        history: [A2AMessage]? = nil,
        artifacts: [A2AArtifact]? = nil,
        metadata: JsonMap? = nil,
        lastUpdated: Int? = nil,
        kind: String = "task"
    ) {
        self.id = id
        self.contextId = contextId
        self.status = status
        self.history = history
        self.artifacts = artifacts
        self.metadata = metadata
        self.lastUpdated = lastUpdated
        self.kind = kind
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = [
            "id": id,
            "contextId": contextId,
            "status": status.toJSON(),
            "kind": kind
        ]
        if let history { json["history"] = history.map { $0.toJSON() } }
        if let artifacts { json["artifacts"] = artifacts.map { $0.toJSON() } }
        if let metadata { json["metadata"] = metadata }
        if let lastUpdated { json["lastUpdated"] = lastUpdated }
        return json
    }

    public static func fromJSON(_ json: JsonMap) -> A2ATask? {
        guard let id = json["id"] as? String,
              let contextId = json["contextId"] as? String,
              let statusJson = json["status"] as? JsonMap,
              let status = A2ATaskStatus.fromJSON(statusJson) else { return nil }

        var history: [A2AMessage]? = nil
        if let hArr = json["history"] as? [JsonMap] {
            history = hArr.compactMap { A2AMessage.fromJSON($0) }
        }
        var artifacts: [A2AArtifact]? = nil
        if let aArr = json["artifacts"] as? [JsonMap] {
            artifacts = aArr.compactMap { A2AArtifact.fromJSON($0) }
        }

        return A2ATask(
            id: id,
            contextId: contextId,
            status: status,
            history: history,
            artifacts: artifacts,
            metadata: json["metadata"] as? JsonMap,
            lastUpdated: json["lastUpdated"] as? Int,
            kind: json["kind"] as? String ?? "task"
        )
    }
}

// MARK: - Artifact

/// 任务执行期间生成的资源（文件、数据结构等）。
public struct A2AArtifact {
    public let artifactId: String
    public let name: String?
    public let description: String?
    public let parts: [A2APart]
    public let metadata: JsonMap?
    public let extensions: [String]?

    public init(
        artifactId: String,
        name: String? = nil,
        description: String? = nil,
        parts: [A2APart],
        metadata: JsonMap? = nil,
        extensions: [String]? = nil
    ) {
        self.artifactId = artifactId
        self.name = name
        self.description = description
        self.parts = parts
        self.metadata = metadata
        self.extensions = extensions
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = [
            "artifactId": artifactId,
            "parts": parts.map { $0.toJSON() }
        ]
        if let name { json["name"] = name }
        if let description { json["description"] = description }
        if let metadata { json["metadata"] = metadata }
        if let extensions { json["extensions"] = extensions }
        return json
    }

    public static func fromJSON(_ json: JsonMap) -> A2AArtifact? {
        guard let artifactId = json["artifactId"] as? String,
              let partsArr = json["parts"] as? [JsonMap] else { return nil }
        return A2AArtifact(
            artifactId: artifactId,
            name: json["name"] as? String,
            description: json["description"] as? String,
            parts: partsArr.compactMap { A2APart.fromJSON($0) },
            metadata: json["metadata"] as? JsonMap,
            extensions: json["extensions"] as? [String]
        )
    }
}

/// 任务的生命周期状态。
public enum A2ATaskState: String {
    case submitted = "submitted"
    case working = "working"
    case inputRequired = "input-required"
    case completed = "completed"
    case canceled = "canceled"
    case failed = "failed"
    case rejected = "rejected"
    case authRequired = "auth-required"
    case unknown = "unknown"

    /// 是否为终态（完成、取消、失败、拒绝）。
    public var isTerminal: Bool {
        switch self {
        case .completed, .canceled, .failed, .rejected: return true
        default: return false
        }
    }

    /// 是否为错误状态（失败、取消、拒绝）。
    public var isError: Bool {
        switch self {
        case .failed, .canceled, .rejected: return true
        default: return false
        }
    }
}

public struct A2ATaskStatus {
    public let state: A2ATaskState
    public let message: A2AMessage?
    public let timestamp: String?

    public init(state: A2ATaskState, message: A2AMessage? = nil, timestamp: String? = nil) {
        self.state = state
        self.message = message
        self.timestamp = timestamp
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = ["state": state.rawValue]
        if let message { json["message"] = message.toJSON() }
        if let timestamp { json["timestamp"] = timestamp }
        return json
    }

    public static func fromJSON(_ json: JsonMap) -> A2ATaskStatus? {
        guard let stateStr = json["state"] as? String,
              let state = A2ATaskState(rawValue: stateStr) else { return nil }
        var message: A2AMessage? = nil
        if let msgJson = json["message"] as? JsonMap {
            message = A2AMessage.fromJSON(msgJson)
        }
        return A2ATaskStatus(
            state: state,
            message: message,
            timestamp: json["timestamp"] as? String
        )
    }
}

// MARK: - A2AMessage JSON 解析

extension A2AMessage {
    public static func fromJSON(_ json: JsonMap) -> A2AMessage? {
        guard let roleStr = json["role"] as? String,
              let role = A2ARole(rawValue: roleStr),
              let partsArr = json["parts"] as? [JsonMap] else { return nil }
        let parts = partsArr.compactMap { A2APart.fromJSON($0) }
        return A2AMessage(
            messageId: json["messageId"] as? String ?? UUID().uuidString,
            role: role,
            parts: parts,
            taskId: json["taskId"] as? String,
            contextId: json["contextId"] as? String,
            referenceTaskIds: json["referenceTaskIds"] as? [String],
            extensions: json["extensions"] as? [String],
            metadata: json["metadata"] as? JsonMap
        )
    }
}

// MARK: - A2A 事件

/// 从 A2A SSE 流接收到的事件。
public enum A2AEvent {
    case statusUpdate(taskId: String, contextId: String, status: A2ATaskStatus, isFinal: Bool)
    case taskStatusUpdate(taskId: String, contextId: String, status: A2ATaskStatus, isFinal: Bool)
    case artifactUpdate(taskId: String, contextId: String, artifact: A2AArtifact, append: Bool, lastChunk: Bool)

    public var taskId: String {
        switch self {
        case .statusUpdate(let tid, _, _, _): return tid
        case .taskStatusUpdate(let tid, _, _, _): return tid
        case .artifactUpdate(let tid, _, _, _, _): return tid
        }
    }

    public var contextId: String {
        switch self {
        case .statusUpdate(_, let cid, _, _): return cid
        case .taskStatusUpdate(_, let cid, _, _): return cid
        case .artifactUpdate(_, let cid, _, _, _): return cid
        }
    }

    public static func fromJSON(_ json: JsonMap) -> A2AEvent? {
        let kind = json["kind"] as? String ?? ""

        switch kind {
        case "task":
            guard let task = A2ATask.fromJSON(json) else { return nil }
            return .statusUpdate(
                taskId: task.id,
                contextId: task.contextId,
                status: task.status,
                isFinal: false
            )

        case "task-status-update":
            guard let taskId = json["taskId"] as? String,
                  let contextId = json["contextId"] as? String,
                  let statusJson = json["status"] as? JsonMap,
                  let status = A2ATaskStatus.fromJSON(statusJson) else { return nil }
            let isFinal = json["final"] as? Bool ?? false
            return .taskStatusUpdate(taskId: taskId, contextId: contextId, status: status, isFinal: isFinal)

        case "status-update":
            guard let taskId = json["taskId"] as? String,
                  let contextId = json["contextId"] as? String,
                  let statusJson = json["status"] as? JsonMap,
                  let status = A2ATaskStatus.fromJSON(statusJson) else { return nil }
            let isFinal = json["final"] as? Bool ?? false
            return .statusUpdate(taskId: taskId, contextId: contextId, status: status, isFinal: isFinal)

        case "artifact-update":
            guard let taskId = json["taskId"] as? String,
                  let contextId = json["contextId"] as? String,
                  let artifactJson = json["artifact"] as? JsonMap,
                  let artifact = A2AArtifact.fromJSON(artifactJson) else { return nil }
            let append = json["append"] as? Bool ?? false
            let lastChunk = json["lastChunk"] as? Bool ?? false
            return .artifactUpdate(taskId: taskId, contextId: contextId, artifact: artifact, append: append, lastChunk: lastChunk)

        default:
            return nil
        }
    }
}

// MARK: - A2A 错误 (Legacy)

/// Legacy error type kept for backward compatibility. Prefer `A2AException`.
public struct A2AError: LocalizedError {
    public let code: Int
    public let message: String

    public init(code: Int = -1, message: String) {
        self.code = code
        self.message = message
    }

    public var errorDescription: String? { "A2AError(\(code)): \(message)" }
}
