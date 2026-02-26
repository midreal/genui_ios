import UIKit
import Combine

/// A block of styled text with Markdown support.
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
                    if Self.containsMarkdown(text) {
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

    private static func containsMarkdown(_ text: String) -> Bool {
        text.contains("**") || text.contains("*") || text.contains("#") ||
        text.contains("[") || text.contains("`") || text.contains("- ") ||
        text.contains("1. ")
    }

    static func renderMarkdown(_ text: String, variant: String) -> NSAttributedString {
        let baseFont = font(for: variant)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]

        let lines = text.components(separatedBy: "\n")
        var resultParts: [NSAttributedString] = []

        for line in lines {
            var currentLine = line

            if let headingMatch = currentLine.range(of: #"^(#{1,6})\s+(.+)$"#, options: .regularExpression) {
                let fullMatch = String(currentLine[headingMatch])
                let hashCount = fullMatch.prefix(while: { $0 == "#" }).count
                let content = String(fullMatch.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                let headingFont: UIFont
                switch hashCount {
                case 1: headingFont = .systemFont(ofSize: 28, weight: .bold)
                case 2: headingFont = .systemFont(ofSize: 24, weight: .bold)
                case 3: headingFont = .systemFont(ofSize: 20, weight: .semibold)
                case 4: headingFont = .systemFont(ofSize: 18, weight: .semibold)
                case 5: headingFont = .systemFont(ofSize: 16, weight: .medium)
                default: headingFont = .systemFont(ofSize: 15, weight: .medium)
                }
                let attrStr = NSMutableAttributedString(string: content, attributes: [
                    .font: headingFont, .foregroundColor: UIColor.label, .paragraphStyle: paragraphStyle
                ])
                resultParts.append(attrStr)
                continue
            }

            if currentLine.hasPrefix("- ") || currentLine.hasPrefix("* ") {
                currentLine = "•  " + String(currentLine.dropFirst(2))
            } else if let listMatch = currentLine.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
                let num = String(currentLine[listMatch]).trimmingCharacters(in: .whitespaces).dropLast()
                let rest = String(currentLine[listMatch.upperBound...])
                currentLine = "\(num).  " + rest
            }

            let attrStr = NSMutableAttributedString(string: currentLine, attributes: baseAttributes)
            applyInlineFormatting(attrStr, baseFont: baseFont)
            resultParts.append(attrStr)
        }

        let result = NSMutableAttributedString()
        for (i, part) in resultParts.enumerated() {
            result.append(part)
            if i < resultParts.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    private static func applyInlineFormatting(_ attrStr: NSMutableAttributedString, baseFont: UIFont) {
        let text = attrStr.string

        applyPattern(
            attrStr, text: text,
            pattern: "`([^`]+)`",
            transform: { content in
                let codeFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
                return [
                    .font: codeFont,
                    .foregroundColor: UIColor.systemPink,
                    .backgroundColor: UIColor.tertiarySystemFill
                ]
            }
        )

        applyPattern(
            attrStr, text: attrStr.string,
            pattern: "\\*\\*(.+?)\\*\\*",
            transform: { _ in
                [.font: UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold),
                 .foregroundColor: UIColor.label]
            }
        )

        applyPattern(
            attrStr, text: attrStr.string,
            pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)",
            transform: { _ in
                [.font: UIFont.italicSystemFont(ofSize: baseFont.pointSize),
                 .foregroundColor: UIColor.label]
            }
        )

        applyPattern(
            attrStr, text: attrStr.string,
            pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
            transform: { _ in
                [.foregroundColor: UIColor.systemBlue,
                 .underlineStyle: NSUnderlineStyle.single.rawValue]
            },
            useGroup: 1
        )
    }

    private static func applyPattern(
        _ attrStr: NSMutableAttributedString,
        text: String,
        pattern: String,
        transform: (String) -> [NSAttributedString.Key: Any],
        useGroup: Int = 1
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: text),
                  let contentRange = Range(match.range(at: useGroup), in: text) else { continue }
            let content = String(text[contentRange])
            let attrs = transform(content)
            let replacement = NSAttributedString(string: content, attributes: attrs)
            attrStr.replaceCharacters(in: NSRange(fullRange, in: text), with: replacement)
        }
    }
}
