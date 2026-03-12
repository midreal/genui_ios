import Foundation

/// Rich exception hierarchy for A2A client errors, matching Dart's sealed `A2AException`.
public enum A2AException: LocalizedError, Equatable {
    /// JSON-RPC error returned by the server.
    case jsonRpc(code: Int, message: String, data: JsonMap?)
    /// Task not found (JSON-RPC code -32001).
    case taskNotFound(message: String, data: JsonMap?)
    /// Task cannot be canceled (JSON-RPC code -32002).
    case taskNotCancelable(message: String, data: JsonMap?)
    /// Push notifications not supported (JSON-RPC code -32006).
    case pushNotificationNotSupported(message: String, data: JsonMap?)
    /// Push notification config not found (JSON-RPC code -32007).
    case pushNotificationConfigNotFound(message: String, data: JsonMap?)
    /// HTTP transport error.
    case http(statusCode: Int, reason: String?)
    /// Network connectivity issue.
    case network(message: String)
    /// Response parsing error.
    case parsing(message: String)
    /// Unsupported operation.
    case unsupportedOperation(message: String)

    /// Maps a JSON-RPC error object to the appropriate `A2AException` variant.
    public static func fromJSONRPCError(_ error: JsonMap) -> A2AException {
        let code = error["code"] as? Int ?? -1
        let message = error["message"] as? String ?? "Unknown error"
        let data = error["data"] as? JsonMap

        switch code {
        case -32001: return .taskNotFound(message: message, data: data)
        case -32002: return .taskNotCancelable(message: message, data: data)
        case -32006: return .pushNotificationNotSupported(message: message, data: data)
        case -32007: return .pushNotificationConfigNotFound(message: message, data: data)
        default: return .jsonRpc(code: code, message: message, data: data)
        }
    }

    public var errorDescription: String? {
        switch self {
        case .jsonRpc(let code, let msg, _): return "A2A JSON-RPC error (\(code)): \(msg)"
        case .taskNotFound(let msg, _): return "A2A task not found: \(msg)"
        case .taskNotCancelable(let msg, _): return "A2A task not cancelable: \(msg)"
        case .pushNotificationNotSupported(let msg, _): return "Push notification not supported: \(msg)"
        case .pushNotificationConfigNotFound(let msg, _): return "Push notification config not found: \(msg)"
        case .http(let code, let reason): return "A2A HTTP error \(code): \(reason ?? "")"
        case .network(let msg): return "A2A network error: \(msg)"
        case .parsing(let msg): return "A2A parsing error: \(msg)"
        case .unsupportedOperation(let msg): return "A2A unsupported operation: \(msg)"
        }
    }

    public static func == (lhs: A2AException, rhs: A2AException) -> Bool {
        switch (lhs, rhs) {
        case (.jsonRpc(let c1, let m1, _), .jsonRpc(let c2, let m2, _)):
            return c1 == c2 && m1 == m2
        case (.taskNotFound(let m1, _), .taskNotFound(let m2, _)):
            return m1 == m2
        case (.taskNotCancelable(let m1, _), .taskNotCancelable(let m2, _)):
            return m1 == m2
        case (.pushNotificationNotSupported(let m1, _), .pushNotificationNotSupported(let m2, _)):
            return m1 == m2
        case (.pushNotificationConfigNotFound(let m1, _), .pushNotificationConfigNotFound(let m2, _)):
            return m1 == m2
        case (.http(let c1, let r1), .http(let c2, let r2)):
            return c1 == c2 && r1 == r2
        case (.network(let m1), .network(let m2)):
            return m1 == m2
        case (.parsing(let m1), .parsing(let m2)):
            return m1 == m2
        case (.unsupportedOperation(let m1), .unsupportedOperation(let m2)):
            return m1 == m2
        default:
            return false
        }
    }
}
