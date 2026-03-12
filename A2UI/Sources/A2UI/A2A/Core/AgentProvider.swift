import Foundation

/// Information about the provider of an agent.
public struct AgentProvider {
    public let organization: String
    public let url: String?

    public init(organization: String, url: String? = nil) {
        self.organization = organization
        self.url = url
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = ["organization": organization]
        if let url { json["url"] = url }
        return json
    }

    public static func fromJSON(_ json: JsonMap) -> AgentProvider? {
        guard let org = json["organization"] as? String else { return nil }
        return AgentProvider(organization: org, url: json["url"] as? String)
    }
}
