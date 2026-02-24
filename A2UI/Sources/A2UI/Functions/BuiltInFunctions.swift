import Foundation
import Combine

/// Factory for all built-in client functions.
public enum BuiltInFunctions {

    /// Returns all 12 built-in functions.
    public static func all() -> [ClientFunction] {
        [
            RequiredFunction(),
            RegexFunction(),
            LengthFunction(),
            NumericFunction(),
            EmailFunction(),
            FormatStringFunction(),
            FormatNumberFunction(),
            FormatCurrencyFunction(),
            FormatDateFunction(),
            AndFunction(),
            OrFunction(),
            NotFunction(),
        ]
    }
}

// MARK: - Validation Functions

/// Returns an error message if the value is nil or empty, otherwise nil (valid).
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

/// Validates a value against a regex pattern.
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

/// Validates string length is within min/max bounds.
final class LengthFunction: SynchronousClientFunction {
    init() { super.init(name: "length") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"] as? String else { return nil }
        let len = value.count
        if let min = args["min"] as? Int, len < min {
            return "Must be at least \(min) characters"
        }
        if let max = args["max"] as? Int, len > max {
            return "Must be at most \(max) characters"
        }
        return nil
    }
}

/// Validates a numeric value is within min/max bounds.
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

/// Validates that a value is a valid email address.
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

/// String interpolation using `{key}` placeholders.
final class FormatStringFunction: SynchronousClientFunction {
    init() { super.init(name: "formatString") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let template = args["value"] as? String else { return args["value"] }
        var result = template
        for (key, val) in args where key != "value" {
            result = result.replacingOccurrences(of: "{\(key)}", with: "\(val ?? "")")
        }
        return result
    }
}

/// Formats a number with optional decimal places and grouping.
final class FormatNumberFunction: SynchronousClientFunction {
    init() { super.init(name: "formatNumber") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"],
              let number = (value as? NSNumber)?.doubleValue ?? Double("\(value ?? 0)") else {
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

/// Formats a number as currency.
final class FormatCurrencyFunction: SynchronousClientFunction {
    init() { super.init(name: "formatCurrency") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"],
              let number = (value as? NSNumber)?.doubleValue ?? Double("\(value ?? 0)") else {
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

/// Formats a date string using the given pattern.
final class FormatDateFunction: SynchronousClientFunction {
    init() { super.init(name: "formatDate") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let value = args["value"] as? String else { return args["value"] }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: value) else { return value }

        let pattern = args["pattern"] as? String ?? "yyyy-MM-dd"
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

// MARK: - Logic Functions

/// Logical AND over an array of boolean values.
final class AndFunction: SynchronousClientFunction {
    init() { super.init(name: "and") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let values = args["values"] as? [Any] else { return false }
        return values.allSatisfy { ($0 as? Bool) == true }
    }
}

/// Logical OR over an array of boolean values.
final class OrFunction: SynchronousClientFunction {
    init() { super.init(name: "or") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        guard let values = args["values"] as? [Any] else { return false }
        return values.contains { ($0 as? Bool) == true }
    }
}

/// Logical NOT.
final class NotFunction: SynchronousClientFunction {
    init() { super.init(name: "not") }
    override func executeSync(args: JsonMap, context: DataContext) -> Any? {
        let value = args["value"]
        if let b = value as? Bool { return !b }
        return value == nil
    }
}
