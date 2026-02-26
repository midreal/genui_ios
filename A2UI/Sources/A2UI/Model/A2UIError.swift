import Foundation

/// Validation error thrown when A2UI message parsing or schema validation fails.
public struct A2UIValidationError: LocalizedError {
    public let message: String
    public let surfaceId: String?
    public let path: String?
    public let json: Any?
    public let cause: Error?

    public init(
        message: String,
        surfaceId: String? = nil,
        path: String? = nil,
        json: Any? = nil,
        cause: Error? = nil
    ) {
        self.message = message
        self.surfaceId = surfaceId
        self.path = path
        self.json = json
        self.cause = cause
    }

    public var errorDescription: String? {
        var desc = "A2UIValidationError: \(message)"
        if let sid = surfaceId { desc += " (surface: \(sid))" }
        if let p = path { desc += " (path: \(p))" }
        if let c = cause { desc += " (cause: \(c.localizedDescription))" }
        return desc
    }
}
