import Foundation

/// Transport protocol for agent communication.
public enum TransportProtocol: String {
    case jsonrpc = "jsonrpc"
    case grpc = "grpc"
    case httpJson = "http+json"
}

/// An agent endpoint with a specific transport protocol.
public struct AgentInterface {
    public let url: String
    public let transport: TransportProtocol

    public init(url: String, transport: TransportProtocol) {
        self.url = url
        self.transport = transport
    }

    public func toJSON() -> JsonMap {
        ["url": url, "transport": transport.rawValue]
    }

    public static func fromJSON(_ json: JsonMap) -> AgentInterface? {
        guard let url = json["url"] as? String,
              let transportStr = json["transport"] as? String,
              let transport = TransportProtocol(rawValue: transportStr) else { return nil }
        return AgentInterface(url: url, transport: transport)
    }
}
