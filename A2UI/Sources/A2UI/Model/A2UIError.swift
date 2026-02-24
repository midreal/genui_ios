import Foundation

/// Validation error thrown when A2UI message parsing or schema validation fails.
public struct A2UIValidationError: LocalizedError {
    public let message: String
    public let surfaceId: String?
    public let path: String?

    public init(message: String, surfaceId: String? = nil, path: String? = nil) {
        self.message = message
        self.surfaceId = surfaceId
        self.path = path
    }

    public var errorDescription: String? {
        var desc = "A2UIValidationError: \(message)"
        if let sid = surfaceId { desc += " (surface: \(sid))" }
        if let p = path { desc += " (path: \(p))" }
        return desc
    }
}
