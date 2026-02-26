import Foundation
import Combine

/// Parses and evaluates expressions in the A2UI `${expression}` format.
///
/// Supports:
/// - `${/user/name}` — data path references
/// - `${formatCurrency(value: ${/price}, currencyCode: 'USD')}` — nested function calls
/// - Recursive parsing with max depth guard
public final class ExpressionParser {

    private let context: DataContext
    private static let maxRecursionDepth = 100

    public init(context: DataContext) {
        self.context = context
    }

    /// Parses the input string and resolves any embedded `${...}` expressions.
    public func parse(_ input: String, depth: Int = 0) -> AnyPublisher<String, Never> {
        if depth > Self.maxRecursionDepth {
            return Just("[max recursion depth]").eraseToAnyPublisher()
        }
        guard input.contains("${") else {
            return Just(input).eraseToAnyPublisher()
        }
        return parseStringWithInterpolations(input, depth: depth + 1)
            .map { $0.flatMap { "\($0)" } ?? "" }
            .eraseToAnyPublisher()
    }

    // MARK: - Core Parsing

    private func parseStringWithInterpolations(
        _ input: String, depth: Int
    ) -> AnyPublisher<Any?, Never> {
        if depth > Self.maxRecursionDepth {
            return Just(nil).eraseToAnyPublisher()
        }

        var i = input.startIndex
        var parts: [Any] = []

        while i < input.endIndex {
            guard let dollarIdx = input[i...].range(of: "${") else {
                parts.append(String(input[i...]))
                break
            }

            if dollarIdx.lowerBound > input.startIndex {
                let prevIdx = input.index(before: dollarIdx.lowerBound)
                if input[prevIdx] == "\\" {
                    parts.append(String(input[i..<prevIdx]))
                    parts.append("${")
                    i = dollarIdx.upperBound
                    continue
                }
            }

            if dollarIdx.lowerBound > i {
                parts.append(String(input[i..<dollarIdx.lowerBound]))
            }

            let (content, endIndex) = extractExpressionContent(input, from: dollarIdx.upperBound)
            if let endIdx = endIndex {
                let value = evaluateExpression(content, depth: depth + 1)
                parts.append(value)
                i = input.index(after: endIdx)
            } else {
                parts.append(String(input[dollarIdx.lowerBound...]))
                break
            }
        }

        if parts.isEmpty { return Just("" as Any?).eraseToAnyPublisher() }

        if parts.count == 1 {
            if let pub = parts[0] as? AnyPublisher<Any?, Never> { return pub }
            return Just(parts[0] as Any?).eraseToAnyPublisher()
        }

        let streams: [AnyPublisher<Any?, Never>] = parts.map { part in
            if let pub = part as? AnyPublisher<Any?, Never> { return pub }
            return Just(part as Any?).eraseToAnyPublisher()
        }

        return CombineLatestHelper.combineAll(streams)
            .map { values -> Any? in
                values.map { $0.flatMap { "\($0)" } ?? "" }.joined()
            }
            .eraseToAnyPublisher()
    }

    private func extractExpressionContent(
        _ input: String, from start: String.Index
    ) -> (String, String.Index?) {
        var balance = 1
        var i = start
        while i < input.endIndex {
            let c = input[i]
            if c == "{" {
                balance += 1
            } else if c == "}" {
                balance -= 1
                if balance == 0 {
                    return (String(input[start..<i]), i)
                }
            }
            if c == "'" || c == "\"" {
                let quote = c
                i = input.index(after: i)
                while i < input.endIndex {
                    if input[i] == quote {
                        if input.index(before: i) >= start && input[input.index(before: i)] != "\\" {
                            break
                        }
                    }
                    i = input.index(after: i)
                }
            }
            i = input.index(after: i)
        }
        return ("", nil)
    }

    private func evaluateExpression(_ content: String, depth: Int) -> AnyPublisher<Any?, Never> {
        if depth > Self.maxRecursionDepth {
            return Just(nil).eraseToAnyPublisher()
        }

        let trimmed = content.trimmingCharacters(in: .whitespaces)

        if let match = trimmed.range(
            of: #"^([a-zA-Z0-9_]+)\s*\("#,
            options: .regularExpression
        ), trimmed.hasSuffix(")") {
            let funcName = String(trimmed[match].dropLast().trimmingCharacters(in: .whitespaces))
            let argsStart = match.upperBound
            let argsEnd = trimmed.index(before: trimmed.endIndex)
            let argsStr = String(trimmed[argsStart..<argsEnd])
            let args = parseNamedArgs(argsStr, depth: depth + 1)
            return evaluateFunctionCall(name: funcName, args: args, depth: depth)
        }

        return resolvePath(trimmed)
    }

    // MARK: - Function Call Evaluation

    /// Evaluates a function call from a JSON definition `{call: "name", args: {...}}`.
    public func evaluateFunctionCall(definition: JsonMap, depth: Int = 0) -> AnyPublisher<Any?, Never> {
        guard let name = definition["call"] as? String else {
            return Just(nil).eraseToAnyPublisher()
        }
        guard let argsMap = definition["args"] as? JsonMap else {
            return evaluateFunctionCall(name: name, args: [:], depth: depth)
        }

        var resolvedArgs: [String: Any] = [:]
        for (key, value) in argsMap {
            if let str = value as? String, str.contains("${") {
                resolvedArgs[key] = parseStringWithInterpolations(str, depth: depth + 1)
            } else if let map = value as? JsonMap, map["path"] is String {
                resolvedArgs[key] = resolvePath(map["path"] as! String)
            } else if let map = value as? JsonMap, map["call"] is String {
                resolvedArgs[key] = evaluateFunctionCall(definition: map, depth: depth + 1)
            } else {
                resolvedArgs[key] = value
            }
        }

        return evaluateFunctionCall(name: name, args: resolvedArgs, depth: depth)
    }

    private func evaluateFunctionCall(
        name: String, args: [String: Any], depth: Int
    ) -> AnyPublisher<Any?, Never> {
        guard let function = context.getFunction(name: name) else {
            return Just(nil).eraseToAnyPublisher()
        }

        let keys = Array(args.keys)
        var hasStreams = false
        for value in args.values {
            if value is AnyPublisher<Any?, Never> { hasStreams = true; break }
        }

        if !hasStreams {
            var staticArgs = JsonMap()
            for (k, v) in args { staticArgs[k] = v }
            return function.execute(args: staticArgs, context: context)
        }

        let streams: [AnyPublisher<Any?, Never>] = keys.map { key in
            let val = args[key]
            if let pub = val as? AnyPublisher<Any?, Never> { return pub }
            return Just(val).eraseToAnyPublisher()
        }

        return CombineLatestHelper.combineAll(streams)
            .flatMap { [weak self] values -> AnyPublisher<Any?, Never> in
                guard let self = self else { return Just(nil).eraseToAnyPublisher() }
                var resolved = JsonMap()
                for (i, key) in keys.enumerated() {
                    resolved[key] = values[i]
                }
                return function.execute(args: resolved, context: self.context)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Argument Parsing

    private func parseNamedArgs(_ argsStr: String, depth: Int) -> [String: Any] {
        var args: [String: Any] = [:]
        var i = argsStr.startIndex

        while i < argsStr.endIndex {
            skipWhitespace(in: argsStr, at: &i)
            if i >= argsStr.endIndex { break }

            let keyStart = i
            while i < argsStr.endIndex && argsStr[i] != ":" && argsStr[i] != " " && argsStr[i] != "," {
                i = argsStr.index(after: i)
            }
            let key = String(argsStr[keyStart..<i]).trimmingCharacters(in: .whitespaces)

            skipWhitespace(in: argsStr, at: &i)
            guard i < argsStr.endIndex, argsStr[i] == ":" else { break }
            i = argsStr.index(after: i)
            skipWhitespace(in: argsStr, at: &i)

            let (value, nextIdx) = parseValue(in: argsStr, at: i, depth: depth)
            args[key] = value
            i = nextIdx

            skipWhitespace(in: argsStr, at: &i)
            if i < argsStr.endIndex && argsStr[i] == "," {
                i = argsStr.index(after: i)
            }
        }

        return args
    }

    private func parseValue(
        in input: String, at start: String.Index, depth: Int
    ) -> (Any, String.Index) {
        guard start < input.endIndex else { return ("", start) }

        let c = input[start]

        if c == "'" || c == "\"" {
            var i = input.index(after: start)
            while i < input.endIndex {
                if input[i] == c {
                    let val = String(input[input.index(after: start)..<i])
                    if val.contains("${") {
                        let pub = parseStringWithInterpolations(val, depth: depth + 1)
                        return (pub, input.index(after: i))
                    }
                    return (val, input.index(after: i))
                }
                i = input.index(after: i)
            }
            return (String(input[start...]), input.endIndex)
        }

        if c == "$" {
            let next = input.index(after: start)
            if next < input.endIndex && input[next] == "{" {
                let innerStart = input.index(after: next)
                let (content, endIdx) = extractExpressionContent(input, from: innerStart)
                if let endIdx = endIdx {
                    return (evaluateExpression(content, depth: depth + 1), input.index(after: endIdx))
                }
            }
        }

        var i = start
        while i < input.endIndex {
            let ch = input[i]
            if ch == "," || ch == ")" || ch == "}" || ch == " " || ch == "\t" || ch == "\n" {
                break
            }
            i = input.index(after: i)
        }

        let token = String(input[start..<i])
        if token == "true" { return (true, i) }
        if token == "false" { return (false, i) }
        if token == "null" { return (NSNull(), i) }
        if let num = Double(token) { return (num, i) }

        return (resolvePath(token), i)
    }

    private func resolvePath(_ pathStr: String) -> AnyPublisher<Any?, Never> {
        let trimmed = pathStr.trimmingCharacters(in: .whitespaces)
        return context.subscribe(path: DataPath(trimmed))
    }

    private func skipWhitespace(in str: String, at i: inout String.Index) {
        while i < str.endIndex && str[i].isWhitespace {
            i = str.index(after: i)
        }
    }
}
