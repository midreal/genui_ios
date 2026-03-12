import Foundation

/// Parameters for the `tasks/list` JSON-RPC method.
public struct ListTasksParams {
    public let contextId: String?
    public let status: A2ATaskState?
    public let pageSize: Int
    public let pageToken: String?
    public let historyLength: Int
    public let lastUpdatedAfter: String?
    public let includeArtifacts: Bool
    public let metadata: JsonMap?

    public init(
        contextId: String? = nil,
        status: A2ATaskState? = nil,
        pageSize: Int = 50,
        pageToken: String? = nil,
        historyLength: Int = 0,
        lastUpdatedAfter: String? = nil,
        includeArtifacts: Bool = false,
        metadata: JsonMap? = nil
    ) {
        self.contextId = contextId
        self.status = status
        self.pageSize = pageSize
        self.pageToken = pageToken
        self.historyLength = historyLength
        self.lastUpdatedAfter = lastUpdatedAfter
        self.includeArtifacts = includeArtifacts
        self.metadata = metadata
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = [
            "pageSize": pageSize,
            "historyLength": historyLength,
            "includeArtifacts": includeArtifacts
        ]
        if let contextId { json["contextId"] = contextId }
        if let status { json["status"] = status.rawValue }
        if let pageToken { json["pageToken"] = pageToken }
        if let lastUpdatedAfter { json["lastUpdatedAfter"] = lastUpdatedAfter }
        if let metadata { json["metadata"] = metadata }
        return json
    }
}
