import Foundation

/// A specific capability or skill that an agent can perform.
public struct AgentSkill {
    public let id: String
    public let name: String
    public let description: String?
    public let tags: [String]?
    public let examples: [String]?
    public let inputModes: [String]?
    public let outputModes: [String]?
    public let security: [[String: [String]]]?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        tags: [String]? = nil,
        examples: [String]? = nil,
        inputModes: [String]? = nil,
        outputModes: [String]? = nil,
        security: [[String: [String]]]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.examples = examples
        self.inputModes = inputModes
        self.outputModes = outputModes
        self.security = security
    }

    public func toJSON() -> JsonMap {
        var json: JsonMap = ["id": id, "name": name]
        if let description { json["description"] = description }
        if let tags { json["tags"] = tags }
        if let examples { json["examples"] = examples }
        if let inputModes { json["inputModes"] = inputModes }
        if let outputModes { json["outputModes"] = outputModes }
        if let security { json["security"] = security }
        return json
    }

    public static func fromJSON(_ json: JsonMap) -> AgentSkill? {
        guard let id = json["id"] as? String,
              let name = json["name"] as? String else { return nil }
        return AgentSkill(
            id: id,
            name: name,
            description: json["description"] as? String,
            tags: json["tags"] as? [String],
            examples: json["examples"] as? [String],
            inputModes: json["inputModes"] as? [String],
            outputModes: json["outputModes"] as? [String],
            security: json["security"] as? [[String: [String]]]
        )
    }
}
