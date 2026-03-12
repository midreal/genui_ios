import Foundation

/// Response for the `tasks/list` JSON-RPC method.
public struct ListTasksResult {
    public let tasks: [A2ATask]
    public let totalSize: Int?
    public let pageSize: Int?
    public let nextPageToken: String?

    public init(tasks: [A2ATask], totalSize: Int? = nil, pageSize: Int? = nil, nextPageToken: String? = nil) {
        self.tasks = tasks
        self.totalSize = totalSize
        self.pageSize = pageSize
        self.nextPageToken = nextPageToken
    }

    public static func fromJSON(_ json: JsonMap) -> ListTasksResult? {
        guard let tasksArr = json["tasks"] as? [JsonMap] else { return nil }
        return ListTasksResult(
            tasks: tasksArr.compactMap { A2ATask.fromJSON($0) },
            totalSize: json["totalSize"] as? Int,
            pageSize: json["pageSize"] as? Int,
            nextPageToken: json["nextPageToken"] as? String
        )
    }
}
