import UIKit

/// Displays an icon using SF Symbols.
///
/// Parameters:
/// - `icon`: The icon name. Attempts SF Symbol lookup, with a fallback mapping
///   from common Material icon names.
/// - `size`: Icon size in points (default 24).
/// - `color`: Icon tint color name (default "label").
enum IconComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Icon") { context in
            let iconName = context.data["icon"] as? String ?? "questionmark"
            let size = context.data["size"] as? CGFloat ?? 24
            let colorName = context.data["color"] as? String

            let sfName = mapToSFSymbol(iconName)
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
            let image = UIImage(systemName: sfName, withConfiguration: config)
                ?? UIImage(systemName: "questionmark.circle", withConfiguration: config)

            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = resolveColor(colorName)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.setContentHuggingPriority(.required, for: .horizontal)
            imageView.setContentHuggingPriority(.required, for: .vertical)

            return imageView
        }
    }

    /// Maps common Material icon names to SF Symbol equivalents.
    private static func mapToSFSymbol(_ name: String) -> String {
        let mapping: [String: String] = [
            "search": "magnifyingglass",
            "home": "house",
            "settings": "gearshape",
            "person": "person",
            "favorite": "heart",
            "star": "star",
            "check": "checkmark",
            "close": "xmark",
            "add": "plus",
            "remove": "minus",
            "edit": "pencil",
            "delete": "trash",
            "share": "square.and.arrow.up",
            "arrow_back": "chevron.left",
            "arrow_forward": "chevron.right",
            "menu": "line.3.horizontal",
            "more_vert": "ellipsis",
            "more_horiz": "ellipsis",
            "info": "info.circle",
            "warning": "exclamationmark.triangle",
            "error": "xmark.circle",
            "email": "envelope",
            "phone": "phone",
            "location_on": "location",
            "calendar_today": "calendar",
            "access_time": "clock",
            "attach_file": "paperclip",
            "photo": "photo",
            "camera": "camera",
            "notifications": "bell",
            "lock": "lock",
            "visibility": "eye",
            "visibility_off": "eye.slash",
            "thumb_up": "hand.thumbsup",
            "thumb_down": "hand.thumbsdown",
            "shopping_cart": "cart",
            "flight": "airplane",
            "hotel": "building.2",
            "restaurant": "fork.knife",
            "directions_car": "car",
        ]
        return mapping[name] ?? name
    }

    private static func resolveColor(_ name: String?) -> UIColor {
        switch name {
        case "primary", "blue": return .systemBlue
        case "red", "error": return .systemRed
        case "green", "success": return .systemGreen
        case "orange", "warning": return .systemOrange
        case "gray", "grey", "secondary": return .secondaryLabel
        case "white": return .white
        case "black": return .black
        default: return .label
        }
    }
}
