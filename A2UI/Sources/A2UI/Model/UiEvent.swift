import Foundation

/// A user interaction event dispatched from a rendered component.
public struct UiEvent {
    public var data: JsonMap

    public init(data: JsonMap) {
        self.data = data
    }

    public var surfaceId: String? {
        get { data[surfaceIdKey] as? String }
        set { data[surfaceIdKey] = newValue }
    }

    public var widgetId: String? { data["widgetId"] as? String }
    public var eventType: String? { data["eventType"] as? String }
    public var value: Any? { data["value"] }
}

/// A specific user action event (e.g. button tap) that triggers server communication.
public struct UserActionEvent {
    public var data: JsonMap

    public init(
        name: String,
        sourceComponentId: String,
        surfaceId: String? = nil,
        timestamp: Date = Date(),
        context: JsonMap = [:]
    ) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var json: JsonMap = [
            "name": name,
            "sourceComponentId": sourceComponentId,
            "timestamp": formatter.string(from: timestamp),
            "context": context
        ]
        if let sid = surfaceId {
            json[surfaceIdKey] = sid
        }
        self.data = json
    }

    public init(data: JsonMap) {
        self.data = data
    }

    public var name: String { data["name"] as? String ?? "" }
    public var sourceComponentId: String { data["sourceComponentId"] as? String ?? "" }
    public var surfaceId: String? {
        get { data[surfaceIdKey] as? String }
        set { data[surfaceIdKey] = newValue }
    }
    public var context: JsonMap { data["context"] as? JsonMap ?? [:] }

    /// Serializes this event for transmission to the server.
    public func toJSON() -> JsonMap {
        [
            "version": a2uiProtocolVersion,
            "action": data
        ]
    }
}
