import UIKit
import Combine

/// Displays an icon using SF Symbols.
///
/// Parameters:
/// - `icon`: The icon name (supports data binding). Attempts SF Symbol lookup,
///   with a fallback mapping from common Material icon names.
/// - `size`: Icon size in points (default 24).
/// - `color`: Icon tint color name (default "label").
enum IconComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Icon") { context in
            let wrapper = BindableView()
            let size = context.data["size"] as? CGFloat ?? 24
            let colorName = context.data["color"] as? String

            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = resolveColor(colorName)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.setContentHuggingPriority(.required, for: .horizontal)
            imageView.setContentHuggingPriority(.required, for: .vertical)
            wrapper.embed(imageView)

            let iconValue = context.data["icon"] ?? context.data["name"]
            let cancellable = context.dataContext.resolve(iconValue)
                .receive(on: DispatchQueue.main)
                .sink { [weak imageView] value in
                    guard let imageView = imageView else { return }
                    let iconName = value as? String ?? "questionmark"
                    let sfName = mapToSFSymbol(iconName)
                    imageView.image = UIImage(systemName: sfName, withConfiguration: config)
                        ?? UIImage(systemName: "questionmark.circle", withConfiguration: config)
                }
            wrapper.storeCancellable(cancellable)

            return wrapper
        }
    }

    /// Maps Material/Flutter icon names to SF Symbol equivalents.
    /// Covers the full Flutter `AvailableIcons` enum plus common aliases.
    private static func mapToSFSymbol(_ name: String) -> String {
        let mapping: [String: String] = [
            // Flutter AvailableIcons enum (complete coverage)
            "accountCircle": "person.circle",
            "add": "plus",
            "arrowBack": "chevron.left",
            "arrowForward": "chevron.right",
            "attachFile": "paperclip",
            "calendarToday": "calendar",
            "call": "phone.fill",
            "camera": "camera",
            "check": "checkmark",
            "close": "xmark",
            "delete": "trash",
            "download": "arrow.down.circle",
            "edit": "pencil",
            "error": "xmark.circle",
            "event": "calendar.badge.clock",
            "favorite": "heart.fill",
            "favoriteOff": "heart",
            "folder": "folder",
            "help": "questionmark.circle",
            "home": "house",
            "info": "info.circle",
            "locationOn": "location",
            "lock": "lock",
            "lockOpen": "lock.open",
            "mail": "envelope",
            "menu": "line.3.horizontal",
            "moreHoriz": "ellipsis",
            "moreVert": "ellipsis",
            "notifications": "bell",
            "notificationsOff": "bell.slash",
            "payment": "creditcard",
            "person": "person",
            "phone": "phone",
            "photo": "photo",
            "print": "printer",
            "refresh": "arrow.clockwise",
            "search": "magnifyingglass",
            "send": "paperplane",
            "settings": "gearshape",
            "share": "square.and.arrow.up",
            "shoppingCart": "cart",
            "star": "star.fill",
            "starHalf": "star.leadinghalf.filled",
            "starOff": "star",
            "upload": "arrow.up.circle",
            "visibility": "eye",
            "visibilityOff": "eye.slash",
            "warning": "exclamationmark.triangle",

            // Underscore aliases for backward compatibility
            "arrow_back": "chevron.left",
            "arrow_forward": "chevron.right",
            "attach_file": "paperclip",
            "calendar_today": "calendar",
            "access_time": "clock",
            "checkCircle": "checkmark.circle",
            "check_circle": "checkmark.circle",
            "dashboard": "square.grid.2x2",
            "directions_car": "car",
            "email": "envelope",
            "flight": "airplane",
            "hotel": "building.2",
            "location_on": "location",
            "more_horiz": "ellipsis",
            "more_vert": "ellipsis",
            "remove": "minus",
            "restaurant": "fork.knife",
            "shopping_cart": "cart",
            "thumb_down": "hand.thumbsdown",
            "thumb_up": "hand.thumbsup",
            "visibility_off": "eye.slash",
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
