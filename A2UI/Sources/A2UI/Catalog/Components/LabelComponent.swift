import UIKit
import Combine

/// A constrained text component for the Macaron design system.
///
/// Parameters:
/// - `text`: The text to display (literal or data-bound).
/// - `color`: One of `label`, `secondary`, `tertiary`.
/// - `variant`: One of `title`, `body`, `bodySemibold`, `bodySans`,
///   `bodySansSemibold`, `subheadline`, `subheadlineSemibold`, `caption`,
///   `captionSemibold`.
enum LabelComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Label") { context in
            let wrapper = BindableView()
            let label = UILabel()
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            wrapper.embed(label)

            let colorName = context.data["color"] as? String ?? "label"
            let variant = context.data["variant"] as? String ?? "body"

            let textDef = context.data["text"]
            let cancellable = BoundValueHelpers.resolveString(textDef, context: context.dataContext)
                .receive(on: DispatchQueue.main)
                .sink { [weak label, weak wrapper] value in
                    guard let label = label else { return }
                    let text = value ?? ""
                    if text.isEmpty {
                        label.text = nil
                        return
                    }

                    let textColor = resolveTextColor(
                        colorName: colorName,
                        buttonStyle: wrapper?.macaronButtonStyle(),
                        selectionSelected: wrapper?.macaronSelectionSelected()
                    )
                    let font = resolveFont(variant: variant)
                    let lineHeight = resolveLineHeight(variant: variant)

                    let paragraphStyle = NSMutableParagraphStyle()
                    let fontLineHeight = font.lineHeight
                    let targetLineHeight = font.pointSize * lineHeight
                    if targetLineHeight > fontLineHeight {
                        paragraphStyle.lineSpacing = targetLineHeight - fontLineHeight
                    }

                    label.attributedText = NSAttributedString(
                        string: text,
                        attributes: [
                            .font: font,
                            .foregroundColor: textColor,
                            .paragraphStyle: paragraphStyle,
                        ]
                    )
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }
    }

    // MARK: - Style Resolution

    private static func resolveTextColor(
        colorName: String,
        buttonStyle: MacaronButtonStyle?,
        selectionSelected: Bool?
    ) -> UIColor {
        if let style = buttonStyle {
            switch style {
            case .primary: return MacaronColors.primaryButtonLight
            case .secondary: return MacaronColors.label
            case .plain: return resolveBaseColor(colorName)
            }
        }
        if selectionSelected == true {
            return MacaronColors.selectionActive
        }
        return resolveBaseColor(colorName)
    }

    private static func resolveBaseColor(_ name: String) -> UIColor {
        switch name {
        case "secondary": return MacaronColors.secondary
        case "tertiary": return MacaronColors.tertiary
        default: return MacaronColors.label
        }
    }

    static func resolveFont(variant: String) -> UIFont {
        switch variant {
        case "title":
            return serifFont(size: 20, weight: .semibold)
        case "bodySemibold":
            return serifFont(size: 16, weight: .semibold)
        case "bodySans":
            return sansFont(size: 16, weight: .regular)
        case "bodySansSemibold":
            return sansFont(size: 16, weight: .semibold)
        case "subheadline":
            return sansFont(size: 14, weight: .regular)
        case "subheadlineSemibold":
            return sansFont(size: 14, weight: .semibold)
        case "caption":
            return sansFont(size: 12, weight: .regular)
        case "captionSemibold":
            return sansFont(size: 12, weight: .semibold)
        default: // "body"
            return serifFont(size: 16, weight: .regular)
        }
    }

    static func resolveLineHeight(variant: String) -> CGFloat {
        switch variant {
        case "title": return 1.60
        case "body", "bodySemibold", "bodySans", "bodySansSemibold": return 1.63
        case "subheadline", "subheadlineSemibold": return 1.86
        case "caption", "captionSemibold": return 1.50
        default: return 1.63
        }
    }

    private static func serifFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if let font = UIFont(name: "NotoSerif", size: size) {
            return font
        }
        if let descriptor = UIFont.systemFont(ofSize: size, weight: weight)
            .fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return .systemFont(ofSize: size, weight: weight)
    }

    private static func sansFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if let font = UIFont(name: "NotoSans-Regular", size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: weight)
    }
}
