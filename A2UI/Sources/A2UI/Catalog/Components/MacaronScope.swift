import UIKit

/// Macaron design system scope types, passed through the view hierarchy
/// via `MacaronScopeStorage` attached to ancestor views.
///
/// Mirrors the Flutter `MacaronCardScope`, `MacaronButtonScope`, and
/// `MacaronSelectionItemScope` InheritedWidgets.

// MARK: - Button Style

enum MacaronButtonStyle {
    case primary, secondary, plain
}

// MARK: - Scope Storage

/// Lightweight key-value store attached to any UIView in the hierarchy.
/// Child views walk up the responder chain to read ancestor scopes.
final class MacaronScopeStorage {
    var cardActive: Bool?
    var buttonStyle: MacaronButtonStyle?
    var selectionSelected: Bool?
}

private var scopeKey: UInt8 = 0

extension UIView {

    /// Lazily-created scope storage for this specific view.
    var macaronScope: MacaronScopeStorage {
        if let existing = objc_getAssociatedObject(self, &scopeKey) as? MacaronScopeStorage {
            return existing
        }
        let storage = MacaronScopeStorage()
        objc_setAssociatedObject(self, &scopeKey, storage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return storage
    }

    /// Finds the nearest ancestor (including self) that has a non-nil card scope.
    func macaronCardActive() -> Bool {
        var current: UIView? = self
        while let view = current {
            if let active = (objc_getAssociatedObject(view, &scopeKey) as? MacaronScopeStorage)?.cardActive {
                return active
            }
            current = view.superview
        }
        return false
    }

    /// Finds the nearest ancestor button style, or nil.
    func macaronButtonStyle() -> MacaronButtonStyle? {
        var current: UIView? = self
        while let view = current {
            if let style = (objc_getAssociatedObject(view, &scopeKey) as? MacaronScopeStorage)?.buttonStyle {
                return style
            }
            current = view.superview
        }
        return nil
    }

    /// Finds the nearest ancestor selection-item scope, or nil.
    func macaronSelectionSelected() -> Bool? {
        var current: UIView? = self
        while let view = current {
            if let selected = (objc_getAssociatedObject(view, &scopeKey) as? MacaronScopeStorage)?.selectionSelected {
                return selected
            }
            current = view.superview
        }
        return nil
    }
}

// MARK: - Macaron Colors

enum MacaronColors {
    static let label        = UIColor(red: 0x16/255, green: 0x16/255, blue: 0x15/255, alpha: 1)
    static let secondary    = UIColor(red: 0x59/255, green: 0x58/255, blue: 0x56/255, alpha: 1)
    static let tertiary     = UIColor(red: 0xAB/255, green: 0xAA/255, blue: 0xA6/255, alpha: 1)
    static let selectionActive = UIColor(red: 0x8C/255, green: 0xA6/255, blue: 0x2A/255, alpha: 1)
    static let cardBackground  = UIColor(red: 0xF9/255, green: 0xF7/255, blue: 0xF1/255, alpha: 1)
    static let cardBorder      = UIColor(red: 0xDF/255, green: 0xDD/255, blue: 0xD7/255, alpha: 1)
    static let trackBackground = UIColor(red: 0xE9/255, green: 0xE7/255, blue: 0xE2/255, alpha: 1)
    static let danger          = UIColor(red: 0xF6/255, green: 0x3B/255, blue: 0x39/255, alpha: 1)
    static let primaryButtonLight = UIColor(red: 0xFF/255, green: 0xFD/255, blue: 0xF7/255, alpha: 1)
    static let gradientStart   = UIColor(red: 0xFF/255, green: 0xC3/255, blue: 0x00/255, alpha: 1)
    static let gradientMid     = UIColor(red: 0xFF/255, green: 0x5A/255, blue: 0x70/255, alpha: 1)
    static let gradientEnd     = UIColor(red: 0xF6/255, green: 0x3B/255, blue: 0x3B/255, alpha: 1)
}
