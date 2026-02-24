import Foundation

/// Represents a path in the data model, either absolute or relative.
///
/// Paths use `/` as separator. Absolute paths start with `/`.
/// Supports numeric segments for array indexing (e.g. `/hotels/0/name`).
public struct DataPath: Hashable, CustomStringConvertible {

    /// The individual segments of the path.
    public let segments: [String]

    /// Whether the path is absolute (starts with `/`).
    public let isAbsolute: Bool

    private static let separator: Character = "/"

    // MARK: - Initializers

    /// Creates a `DataPath` from a string representation.
    public init(_ path: String) {
        if path == "/" {
            self = DataPath.root
            return
        }
        let parts = path.split(separator: DataPath.separator, omittingEmptySubsequences: true)
            .map(String.init)
        self.segments = parts
        self.isAbsolute = path.hasPrefix("/")
    }

    /// Internal memberwise initializer.
    init(segments: [String], isAbsolute: Bool) {
        self.segments = segments
        self.isAbsolute = isAbsolute
    }

    // MARK: - Constants

    /// The root path (`/`).
    public static let root = DataPath(segments: [], isAbsolute: true)

    // MARK: - Computed Properties

    /// The last segment of the path, or an empty string if the path has no segments.
    public var basename: String {
        segments.last ?? ""
    }

    /// The path without the last segment.
    public var dirname: DataPath {
        if segments.isEmpty { return self }
        return DataPath(segments: Array(segments.dropLast()), isAbsolute: isAbsolute)
    }

    // MARK: - Operations

    /// Joins this path with another path.
    ///
    /// If `other` is absolute, it is returned as-is.
    /// Joining two absolute paths is a programming error.
    public func join(_ other: DataPath) -> DataPath {
        if other.isAbsolute {
            return other
        }
        return DataPath(segments: segments + other.segments, isAbsolute: isAbsolute)
    }

    /// Returns whether this path starts with the given prefix path.
    public func starts(with other: DataPath) -> Bool {
        if other.isAbsolute && !isAbsolute { return false }
        if other.segments.count > segments.count { return false }
        for i in 0..<other.segments.count {
            if segments[i] != other.segments[i] { return false }
        }
        return true
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        let joined = segments.joined(separator: "/")
        return isAbsolute ? "/\(joined)" : joined
    }
}
