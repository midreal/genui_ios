import Foundation

/// OpenAPI-style security scheme for agent authentication.
public enum SecurityScheme {
    case apiKey(name: String, `in`: String)
    case http(scheme: String, bearerFormat: String?)
    case oauth2(flows: OAuthFlows)
    case openIdConnect(openIdConnectUrl: String)
    case mutualTls

    public static func fromJSON(_ json: JsonMap) -> SecurityScheme? {
        guard let type = json["type"] as? String else { return nil }
        switch type {
        case "apiKey":
            guard let name = json["name"] as? String,
                  let inStr = json["in"] as? String else { return nil }
            return .apiKey(name: name, in: inStr)
        case "http":
            guard let scheme = json["scheme"] as? String else { return nil }
            return .http(scheme: scheme, bearerFormat: json["bearerFormat"] as? String)
        case "oauth2":
            guard let flowsJson = json["flows"] as? JsonMap else { return nil }
            return .oauth2(flows: OAuthFlows.fromJSON(flowsJson))
        case "openIdConnect":
            guard let url = json["openIdConnectUrl"] as? String else { return nil }
            return .openIdConnect(openIdConnectUrl: url)
        case "mutualTLS":
            return .mutualTls
        default:
            return nil
        }
    }
}

public struct OAuthFlows {
    public let implicit: OAuthFlow?
    public let password: OAuthFlow?
    public let clientCredentials: OAuthFlow?
    public let authorizationCode: OAuthFlow?

    public init(
        implicit: OAuthFlow? = nil,
        password: OAuthFlow? = nil,
        clientCredentials: OAuthFlow? = nil,
        authorizationCode: OAuthFlow? = nil
    ) {
        self.implicit = implicit
        self.password = password
        self.clientCredentials = clientCredentials
        self.authorizationCode = authorizationCode
    }

    public static func fromJSON(_ json: JsonMap) -> OAuthFlows {
        OAuthFlows(
            implicit: (json["implicit"] as? JsonMap).flatMap { OAuthFlow.fromJSON($0) },
            password: (json["password"] as? JsonMap).flatMap { OAuthFlow.fromJSON($0) },
            clientCredentials: (json["clientCredentials"] as? JsonMap).flatMap { OAuthFlow.fromJSON($0) },
            authorizationCode: (json["authorizationCode"] as? JsonMap).flatMap { OAuthFlow.fromJSON($0) }
        )
    }
}

public struct OAuthFlow {
    public let authorizationUrl: String?
    public let tokenUrl: String?
    public let refreshUrl: String?
    public let scopes: [String: String]?

    public init(
        authorizationUrl: String? = nil,
        tokenUrl: String? = nil,
        refreshUrl: String? = nil,
        scopes: [String: String]? = nil
    ) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }

    public static func fromJSON(_ json: JsonMap) -> OAuthFlow? {
        OAuthFlow(
            authorizationUrl: json["authorizationUrl"] as? String,
            tokenUrl: json["tokenUrl"] as? String,
            refreshUrl: json["refreshUrl"] as? String,
            scopes: json["scopes"] as? [String: String]
        )
    }
}
