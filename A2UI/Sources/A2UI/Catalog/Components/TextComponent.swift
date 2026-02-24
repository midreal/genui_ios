import UIKit
import Combine

/// A block of styled text with optional Markdown support.
///
/// Parameters:
/// - `text`: The text to display (literal or data binding).
/// - `variant`: Style hint — "h1", "h2", "h3", "h4", "h5", "caption", "body".
enum TextComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Text") { context in
            let wrapper = BindableView()
            let label = UILabel()
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            wrapper.embed(label)

            let variant = context.data["variant"] as? String ?? "body"
            label.font = Self.font(for: variant)

            let textValue = context.data["text"]
            let cancellable = context.dataContext.resolve(textValue)
                .receive(on: DispatchQueue.main)
                .sink { [weak label] value in
                    guard let label = label else { return }
                    let text = (value as? String) ?? "\(value ?? "")"
                    if text.contains("**") || text.contains("*") || text.contains("#") || text.contains("[") {
                        label.attributedText = Self.renderMarkdown(text, variant: variant)
                    } else {
                        label.text = text
                    }
                }
            wrapper.storeCancellable(cancellable)

            return wrapper
        }
    }

    static func font(for variant: String) -> UIFont {
        switch variant {
        case "h1": return .systemFont(ofSize: 28, weight: .bold)
        case "h2": return .systemFont(ofSize: 24, weight: .bold)
        case "h3": return .systemFont(ofSize: 20, weight: .semibold)
        case "h4": return .systemFont(ofSize: 18, weight: .semibold)
        case "h5": return .systemFont(ofSize: 16, weight: .medium)
        case "caption": return .systemFont(ofSize: 12, weight: .regular)
        default: return .systemFont(ofSize: 15, weight: .regular)
        }
    }

    static func renderMarkdown(_ text: String, variant: String) -> NSAttributedString {
        let baseFont = font(for: variant)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: UIColor.label
        ]

        let result = NSMutableAttributedString(string: text, attributes: baseAttributes)

        // Bold: **text**
        let boldPattern = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
        if let matches = boldPattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: text),
                      let contentRange = Range(match.range(at: 1), in: text) else { continue }
                let content = String(text[contentRange])
                let boldFont = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
                let replacement = NSAttributedString(string: content, attributes: [
                    .font: boldFont, .foregroundColor: UIColor.label
                ])
                result.replaceCharacters(in: NSRange(fullRange, in: text), with: replacement)
            }
        }

        // Italic: *text*
        let italicPattern = try? NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)")
        if let matches = italicPattern?.matches(in: result.string, range: NSRange(location: 0, length: result.length)) {
            for match in matches.reversed() {
                let fullRange = match.range
                let contentRange = match.range(at: 1)
                let content = (result.string as NSString).substring(with: contentRange)
                let italicFont = UIFont.italicSystemFont(ofSize: baseFont.pointSize)
                let replacement = NSAttributedString(string: content, attributes: [
                    .font: italicFont, .foregroundColor: UIColor.label
                ])
                result.replaceCharacters(in: fullRange, with: replacement)
            }
        }

        return result
    }
}
