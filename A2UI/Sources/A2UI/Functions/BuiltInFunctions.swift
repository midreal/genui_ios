import Foundation
import Combine
import UIKit

/// Factory for all built-in client functions.
public enum BuiltInFunctions {

    /// Returns all 14 built-in functions.
    public static func all() -> [ClientFunction] {
        [
            RequiredFunction(),
            RegexFunction(),
            LengthFunction(),
            NumericFunction(),
            EmailFunction(),
            FormatStringFunction(),
            OpenUrlFunction(),
            FormatNumberFunction(),
            FormatCurrencyFunction(),
            FormatDateFunction(),
            PluralizeFunction(),
            AndFunction(),
            OrFunction(),
            NotFunction(),
        ]
    }
}

// MARK: - Validation Functions

final class RequiredFunction: SynchronousClientFunction {
    init() { super.init(name: "required") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        let value = args["value"]
        if value == nil { return "This field is required" }
        if let str = value as? String, str.trimmingCharacters(in: .whitespaces).isEmpty {
            return "This field is required"
        }
        return nil
    }
}

final class RegexFunction: SynchronousClientFunction {
    init() { super.init(name: "regex") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"] as? String,
              let pattern = args["pattern"] as? String else { return nil }
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        if regex?.firstMatch(in: value, range: range) == nil {
            return args["message"] as? String ?? "Invalid format"
        }
        return nil
    }
}

final class LengthFunction: SynchronousClientFunction {
    init() { super.init(name: "length") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        let value = args["value"]
        var length = 0
        if value == nil {
            length = 0
        } else if let str = value as? String {
            length = str.count
        } else if let arr = value as? [Any] {
            length = arr.count
        } else if let dict = value as? JsonMap {
            length = dict.count
        }

        if args["min"] != nil || args["max"] != nil {
            if let min = args["min"] as? Int, length < min { return false }
            if let max = args["max"] as? Int, length > max { return false }
            return true
        }
        return length
    }
}

final class NumericFunction: SynchronousClientFunction {
    init() { super.init(name: "numeric") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"] else { return nil }
        let numValue: Double
        if let n = value as? NSNumber { numValue = n.doubleValue }
        else if let s = value as? String, let n = Double(s) { numValue = n }
        else { return "Must be a number" }

        if let min = (args["min"] as? NSNumber)?.doubleValue, numValue < min {
            return "Must be at least \(min)"
        }
        if let max = (args["max"] as? NSNumber)?.doubleValue, numValue > max {
            return "Must be at most \(max)"
        }
        return nil
    }
}

final class EmailFunction: SynchronousClientFunction {
    init() { super.init(name: "email") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"] as? String else { return nil }
        let pattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        if regex?.firstMatch(in: value, range: range) == nil {
            return "Invalid email address"
        }
        return nil
    }
}

// MARK: - Format Functions

/// String interpolation using `${expression}` syntax (with ExpressionParser)
/// and simple `{key}` placeholder fallback.
final class FormatStringFunction: ClientFunction {
    let name = "formatString"

    func execute(args: JsonMap, context: DataContext) -> AnyPublisher<Any?, Never> {
        guard let template = args["value"] as? String else {
            return Just(args["value"]).eraseToAnyPublisher()
        }

        if template.contains("${") {
            let parser = ExpressionParser(context: context)
            return parser.parse(template)
                .map { $0 as Any? }
                .eraseToAnyPublisher()
        }

        var result = template
        for (key, val) in args where key != "value" {
            result = result.replacingOccurrences(of: "{\(key)}", with: "\(val)")
        }
        return Just(result as Any?).eraseToAnyPublisher()
    }
}

/// Opens an external URL.
final class OpenUrlFunction: SynchronousClientFunction {
    init() { super.init(name: "openUrl") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let urlStr = args["url"] as? String,
              let url = URL(string: urlStr) else { return false }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
        return true
    }
}

final class FormatNumberFunction: SynchronousClientFunction {
    init() { super.init(name: "formatNumber") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"],
              let number = (value as? NSNumber)?.doubleValue ?? Double("\(value)") else {
            return "\(args["value"] ?? "")"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let dp = args["decimalPlaces"] as? Int {
            formatter.minimumFractionDigits = dp
            formatter.maximumFractionDigits = dp
        }
        if let grouping = args["useGrouping"] as? Bool {
            formatter.usesGroupingSeparator = grouping
        }
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

final class FormatCurrencyFunction: SynchronousClientFunction {
    init() { super.init(name: "formatCurrency") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"],
              let number = (value as? NSNumber)?.doubleValue ?? Double("\(value)") else {
            return "\(args["value"] ?? "")"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if let code = args["currencyCode"] as? String {
            formatter.currencyCode = code
        }
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

final class FormatDateFunction: SynchronousClientFunction {
    init() { super.init(name: "formatDate") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"] as? String else { return args["value"] }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date: Date?
        date = isoFormatter.date(from: value) ?? {
            let alt = ISO8601DateFormatter()
            alt.formatOptions = [.withInternetDateTime]
            return alt.date(from: value)
        }()

        guard let parsedDate = date else { return value }
        let pattern = args["pattern"] as? String ?? "yyyy-MM-dd"
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: parsedDate)
    }
}

/// Count-based pluralization with zero/one/other templates.
final class PluralizeFunction: SynchronousClientFunction {
    init() { super.init(name: "pluralize") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let count = (args["count"] as? NSNumber)?.intValue else { return "" }
        if count == 0, let zero = args["zero"] as? String { return zero }
        if count == 1, let one = args["one"] as? String { return one }
        return args["other"] as? String ?? ""
    }
}

// MARK: - Logic Functions

final class AndFunction: SynchronousClientFunction {
    init() { super.init(name: "and") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let values = args["values"] as? [Any] else { return false }
        return values.allSatisfy { isTruthy($0) }
    }
}

final class OrFunction: SynchronousClientFunction {
    init() { super.init(name: "or") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let values = args["values"] as? [Any] else { return false }
        return values.contains { isTruthy($0) }
    }
}

final class NotFunction: SynchronousClientFunction {
    init() { super.init(name: "not") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        let value = args["value"]
        if let b = value as? Bool { return !b }
        return value == nil
    }
}

private func isTruthy(_ value: Any?) -> Bool {
    if let b = value as? Bool { return b }
    if value == nil { return false }
    return true
}
