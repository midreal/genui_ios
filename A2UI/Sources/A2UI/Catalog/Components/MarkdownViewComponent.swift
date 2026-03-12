import UIKit
import Combine

/// A Markdown viewer component for the Macaron design system.
///
/// Renders general-purpose Markdown content from a string reference.
///
/// Parameters:
/// - `text`: Markdown text content to render.
enum MarkdownViewComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "MarkdownView") { context in
            let wrapper = BindableView()

            let label = UILabel()
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            wrapper.embed(label)

            let textDef = context.data["text"]
            let cancellable = BoundValueHelpers.resolveString(textDef, context: context.dataContext)
                .receive(on: DispatchQueue.main)
                .sink { [weak label] value in
                    guard let label = label else { return }
                    let text = value ?? ""
                    if text.isEmpty {
                        label.attributedText = nil
                        return
                    }
                    label.attributedText = renderMarkdown(text)
                }
            wrapper.storeCancellable(cancellable)

            return wrapper
        }
    }

    private static func renderMarkdown(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let bodyFont = serifFont(size: 16, weight: .regular)
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: MacaronColors.label,
            .paragraphStyle: paragraphStyle,
        ]

        let h1Font = serifFont(size: 24, weight: .semibold)
        let h2Font = serifFont(size: 20, weight: .semibold)
        let h3Font = serifFont(size: 18, weight: .semibold)

        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("### ") {
                let content = String(trimmed.dropFirst(4))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: h3Font,
                    .foregroundColor: MacaronColors.label,
                    .paragraphStyle: paragraphStyle,
                ]
                result.append(NSAttributedString(string: content, attributes: attrs))
            } else if trimmed.hasPrefix("## ") {
                let content = String(trimmed.dropFirst(3))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: h2Font,
                    .foregroundColor: MacaronColors.label,
                    .paragraphStyle: paragraphStyle,
                ]
                result.append(NSAttributedString(string: content, attributes: attrs))
            } else if trimmed.hasPrefix("# ") {
                let content = String(trimmed.dropFirst(2))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: h1Font,
                    .foregroundColor: MacaronColors.label,
                    .paragraphStyle: paragraphStyle,
                ]
                result.append(NSAttributedString(string: content, attributes: attrs))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = "  • " + String(trimmed.dropFirst(2))
                result.append(NSAttributedString(string: content, attributes: bodyAttrs))
            } else {
                let processed = processInlineMarkdown(trimmed, bodyAttrs: bodyAttrs)
                result.append(processed)
            }

            if i < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
            }
        }

        return result
    }

    private static func processInlineMarkdown(_ text: String, bodyAttrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            if let boldRange = remaining.range(of: "**") {
                let before = String(remaining[remaining.startIndex..<boldRange.lowerBound])
                if !before.isEmpty {
                    result.append(NSAttributedString(string: before, attributes: bodyAttrs))
                }
                remaining = remaining[boldRange.upperBound...]
                if let endBold = remaining.range(of: "**") {
                    let boldText = String(remaining[remaining.startIndex..<endBold.lowerBound])
                    var boldAttrs = bodyAttrs
                    boldAttrs[.font] = serifFont(size: 16, weight: .semibold)
                    result.append(NSAttributedString(string: boldText, attributes: boldAttrs))
                    remaining = remaining[endBold.upperBound...]
                } else {
                    result.append(NSAttributedString(string: "**", attributes: bodyAttrs))
                }
            } else if let italicRange = remaining.range(of: "*") {
                let before = String(remaining[remaining.startIndex..<italicRange.lowerBound])
                if !before.isEmpty {
                    result.append(NSAttributedString(string: before, attributes: bodyAttrs))
                }
                remaining = remaining[italicRange.upperBound...]
                if let endItalic = remaining.range(of: "*") {
                    let italicText = String(remaining[remaining.startIndex..<endItalic.lowerBound])
                    var italicAttrs = bodyAttrs
                    if let descriptor = (bodyAttrs[.font] as? UIFont)?.fontDescriptor.withSymbolicTraits(.traitItalic) {
                        italicAttrs[.font] = UIFont(descriptor: descriptor, size: 0)
                    }
                    result.append(NSAttributedString(string: italicText, attributes: italicAttrs))
                    remaining = remaining[endItalic.upperBound...]
                } else {
                    result.append(NSAttributedString(string: "*", attributes: bodyAttrs))
                }
            } else if let codeRange = remaining.range(of: "`") {
                let before = String(remaining[remaining.startIndex..<codeRange.lowerBound])
                if !before.isEmpty {
                    result.append(NSAttributedString(string: before, attributes: bodyAttrs))
                }
                remaining = remaining[codeRange.upperBound...]
                if let endCode = remaining.range(of: "`") {
                    let codeText = String(remaining[remaining.startIndex..<endCode.lowerBound])
                    var codeAttrs = bodyAttrs
                    codeAttrs[.font] = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                    codeAttrs[.foregroundColor] = MacaronColors.secondary
                    codeAttrs[.backgroundColor] = UIColor(red: 0xEF/255, green: 0xED/255, blue: 0xE6/255, alpha: 1)
                    result.append(NSAttributedString(string: codeText, attributes: codeAttrs))
                    remaining = remaining[endCode.upperBound...]
                } else {
                    result.append(NSAttributedString(string: "`", attributes: bodyAttrs))
                }
            } else {
                result.append(NSAttributedString(string: String(remaining), attributes: bodyAttrs))
                break
            }
        }

        return result
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
}
