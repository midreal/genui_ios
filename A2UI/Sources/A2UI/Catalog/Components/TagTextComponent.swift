import UIKit
import Combine

/// A segmented text label joining items with ` · `.
///
/// Parameters:
/// - `segments`: Path or literalArray of `{text, style?}` objects.
///   Style values: `default`, `secondary`, `tertiary`, `highlight`.
enum TagTextComponent {

    private static let separatorText = " · "
    private static let fontSize: CGFloat = 12
    private static let defaultColor = MacaronColors.label
    private static let secondaryColor = MacaronColors.secondary
    private static let tertiaryColor = MacaronColors.tertiary
    private static let highlightColor = MacaronColors.selectionActive
    private static let separatorColor = MacaronColors.secondary

    static func register() -> CatalogItem {
        CatalogItem(name: "TagText") { context in
            let wrapper = BindableView()
            let label = UILabel()
            label.numberOfLines = 0
            wrapper.embed(label)

            let segmentsDef = context.data["segments"]
            let cancellable = context.dataContext.resolve(segmentsDef)
                .receive(on: DispatchQueue.main)
                .sink { [weak label] value in
                    guard let label = label else { return }
                    let segments = parseSegments(value)
                    guard !segments.isEmpty else {
                        label.attributedText = nil
                        return
                    }
                    label.attributedText = buildAttributedString(segments)
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }
    }

    private struct Segment {
        let text: String
        let style: String
    }

    private static func parseSegments(_ value: Any?) -> [Segment] {
        // Handle literalArray or array-from-path
        let rawArray: [Any?]
        if let map = value as? JsonMap {
            rawArray = map["literalArray"] as? [Any?] ?? []
        } else if let arr = value as? [Any?] {
            rawArray = arr
        } else {
            return []
        }

        var result: [Segment] = []
        for item in rawArray {
            guard let dict = item as? JsonMap,
                  let text = dict["text"] as? String,
                  !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let style = dict["style"] as? String ?? "default"
            result.append(Segment(text: text, style: style))
        }
        return result
    }

    private static func resolveSegmentColor(_ style: String) -> UIColor {
        switch style {
        case "secondary": return secondaryColor
        case "tertiary": return tertiaryColor
        case "highlight": return highlightColor
        default: return defaultColor
        }
    }

    private static func buildAttributedString(_ segments: [Segment]) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        let result = NSMutableAttributedString()

        for (i, segment) in segments.enumerated() {
            if i > 0 {
                let sep = NSAttributedString(string: separatorText, attributes: [
                    .font: font,
                    .foregroundColor: separatorColor,
                ])
                result.append(sep)
            }
            let attr = NSAttributedString(string: segment.text, attributes: [
                .font: font,
                .foregroundColor: resolveSegmentColor(segment.style),
            ])
            result.append(attr)
        }
        return result
    }
}
