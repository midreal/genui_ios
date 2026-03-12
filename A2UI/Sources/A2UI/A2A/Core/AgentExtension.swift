import Foundation

/// A protocol extension supported by an agent.
public struct AgentExtension {
    public let uri: String
    public let description: String?
    public let required: Bool
    public let params: JsonMap?

    public init(uri: String, description: String? = nil, required: Bool = false, params: JsonMap? = nil) {
        self.uri = uri
        self.description = description
        self.required = required
        self.params = params
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = ["uri": uri, "required": required]
        if let description { json["description"] = description }
        if let params { json["params"] = params }
        return json
    }

    public static func fromJSON(_ json: JsonMap) -> AgentExtension? {
        guard let uri = json["uri"] as? String else { return nil }
        return AgentExtension(
            uri: uri,
            description: json["description"] as? String,
            required: json["required"] as? Bool ?? false,
            params: json["params"] as? JsonMap
        )
    }
}
