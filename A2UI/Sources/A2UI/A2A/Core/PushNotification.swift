import Foundation

/// Configuration for push notifications.
public struct PushNotificationConfig {
    public let id: String
    public let url: String
    public let token: String?
    public let authentication: PushNotificationAuthenticationInfo?

    public init(id: String, url: String, token: String? = nil, authentication: PushNotificationAuthenticationInfo? = nil) {
        self.id = id
        self.url = url
        self.token = token
        self.authentication = authentication
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = ["id": id, "url": url]
        if let token { json["token"] = token }
        if let authentication { json["authentication"] = authentication.toJSON() }
        return json
    }

    public static func fromJSON(_ json: JsonMap) -> PushNotificationConfig? {
        guard let id = json["id"] as? String,
              let url = json["url"] as? String else { return nil }
        var auth: PushNotificationAuthenticationInfo? = nil
        if let authJson = json["authentication"] as? JsonMap {
            auth = PushNotificationAuthenticationInfo.fromJSON(authJson)
        }
        return PushNotificationConfig(id: id, url: url, token: json["token"] as? String, authentication: auth)
    }
}

/// Authentication info for push notification delivery.
public struct PushNotificationAuthenticationInfo {
    public let schemes: [String]
    public let credentials: String?

    public init(schemes: [String], credentials: String? = nil) {
        self.schemes = schemes
        self.credentials = credentials
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = ["schemes": schemes]
        if let credentials { json["credentials"] = credentials }
        return json
    }

    public static func fromJSON(_ json: JsonMap) -> PushNotificationAuthenticationInfo? {
        guard let schemes = json["schemes"] as? [String] else { return nil }
        return PushNotificationAuthenticationInfo(schemes: schemes, credentials: json["credentials"] as? String)
    }
}

/// Associates a push notification configuration with a specific task.
public struct TaskPushNotificationConfig {
    public let taskId: String
    public let pushNotificationConfig: PushNotificationConfig

    public init(taskId: String, pushNotificationConfig: PushNotificationConfig) {
        self.taskId = taskId
        self.pushNotificationConfig = pushNotificationConfig
    }

    public func toJSON() -> JsonMap {
        [
            "taskId": taskId,
            "pushNotificationConfig": pushNotificationConfig.toJSON()
        ]
    }

    public static func fromJSON(_ json: JsonMap) -> TaskPushNotificationConfig? {
        guard let taskId = json["taskId"] as? String,
              let configJson = json["pushNotificationConfig"] as? JsonMap,
              let config = PushNotificationConfig.fromJSON(configJson) else { return nil }
        return TaskPushNotificationConfig(taskId: taskId, pushNotificationConfig: config)
    }
}
