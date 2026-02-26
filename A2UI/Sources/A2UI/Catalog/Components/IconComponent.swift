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

    /// Maps common Material icon names to SF Symbol equivalents. (43 mappings)
    private static func mapToSFSymbol(_ name: String) -> String {
        let mapping: [String: String] = [
            "accountCircle": "person.circle",
            "add": "plus",
            "arrowBack": "chevron.left",
            "arrow_back": "chevron.left",
            "arrowForward": "chevron.right",
            "arrow_forward": "chevron.right",
            "attach_file": "paperclip",
            "access_time": "clock",
            "calendar_today": "calendar",
            "camera": "camera",
            "check": "checkmark",
            "checkCircle": "checkmark.circle",
            "check_circle": "checkmark.circle",
            "close": "xmark",
            "dashboard": "square.grid.2x2",
            "delete": "trash",
            "directions_car": "car",
            "download": "arrow.down.circle",
            "edit": "pencil",
            "email": "envelope",
            "error": "xmark.circle",
            "favorite": "heart",
            "flight": "airplane",
            "home": "house",
            "hotel": "building.2",
            "info": "info.circle",
            "location_on": "location",
            "lock": "lock",
            "menu": "line.3.horizontal",
            "more_horiz": "ellipsis",
            "more_vert": "ellipsis",
            "notifications": "bell",
            "person": "person",
            "phone": "phone",
            "photo": "photo",
            "refresh": "arrow.clockwise",
            "remove": "minus",
            "restaurant": "fork.knife",
            "search": "magnifyingglass",
            "settings": "gearshape",
            "share": "square.and.arrow.up",
            "shopping_cart": "cart",
            "star": "star",
            "thumb_down": "hand.thumbsdown",
            "thumb_up": "hand.thumbsup",
            "visibility": "eye",
            "visibility_off": "eye.slash",
            "warning": "exclamationmark.triangle",
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
