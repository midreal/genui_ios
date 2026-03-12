import Foundation

/// Selection constraint helpers ported from the Flutter `selection_constraints.dart`.

struct SelectionConstraints {
    let effectiveMaxSelection: Int
    let effectiveRequiredSelection: Int
}

func resolveSelectionConstraints(
    itemCount: Int,
    maxSelection: Int,
    requiredSelection: Int
) -> SelectionConstraints {
    guard itemCount > 0 else {
        return SelectionConstraints(effectiveMaxSelection: 0, effectiveRequiredSelection: 0)
    }
    let effectiveMax = min(max(maxSelection, 1), itemCount)
    let effectiveReq = min(max(requiredSelection, 1), effectiveMax)
    return SelectionConstraints(effectiveMaxSelection: effectiveMax, effectiveRequiredSelection: effectiveReq)
}

func normalizeSelectionValues(
    rawSelection: [Any?],
    items: [JsonMap],
    effectiveMaxSelection: Int
) -> [String] {
    guard effectiveMaxSelection > 0, !rawSelection.isEmpty else { return [] }

    let validValues = Set(items.compactMap { $0["value"] as? String })
    var seen = Set<String>()
    var normalized: [String] = []

    for raw in rawSelection {
        guard let value = raw as? String,
              validValues.contains(value),
              !seen.contains(value) else { continue }
        seen.insert(value)
        normalized.append(value)
        if normalized.count >= effectiveMaxSelection { break }
    }
    return normalized
}

func isSelectionNormalized(_ rawSelection: [Any?]?, _ normalized: [String]) -> Bool {
    guard let raw = rawSelection else { return normalized.isEmpty }
    guard raw.count == normalized.count else { return false }
    for i in 0..<normalized.count {
        guard let s = raw[i] as? String, s == normalized[i] else { return false }
    }
    return true
}
