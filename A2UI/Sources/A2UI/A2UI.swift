// A2UI — Agent-to-UI Protocol v0.9 iOS UIKit Implementation
//
// Public API surface. Import `A2UI` to access all framework types.

@_exported import Foundation
@_exported import UIKit
@_exported import Combine

// MARK: - Protocol Constants

/// The current A2UI protocol version.
public let a2uiProtocolVersion = "v0.9"

/// The JSON key used for surface IDs across all message types.
public let surfaceIdKey = "surfaceId"

/// The default catalog identifier used when none is specified.
public let basicCatalogId = "com.google.genui.basic"

/// Typealias for JSON dictionary used throughout the framework.
public typealias JsonMap = [String: Any]
