import Foundation

/// Lightweight A2UI message validator (Level 1 + Level 2).
///
/// Performs structural and reference integrity checks on raw A2UI JSON
/// before it is deserialized into typed models. Prevents crashes from
/// malformed LLM output. Matches Dart's `A2uiValidator`.
public enum A2uiValidator {

    private static let validActionKeys: Set<String> = [
        "beginRendering", "surfaceUpdate", "dataModelUpdate", "deleteSurface"
    ]

    private static let knownComponentTypes: Set<String> = [
        "Text", "Image", "Icon", "Video", "AudioPlayer", "PhotoInput",
        "Row", "Column", "List",
        "Card", "Tabs", "Divider", "Modal",
        "Button", "CheckBox", "TextField", "DateTimeInput",
        "MultipleChoice", "Slider"
    ]

    // MARK: - L1: Single Message Validation

    /// Validates a single raw A2UI message JSON map.
    /// Returns an array of error strings. Empty means valid.
    public static func validateMessage(_ json: JsonMap) -> [String] {
        var errors = [String]()

        let actionKeys = json.keys.filter { validActionKeys.contains($0) }
        if actionKeys.isEmpty {
            errors.append("No valid action key found. Keys: \(Array(json.keys))")
            return errors
        }
        if actionKeys.count > 1 {
            errors.append("Multiple action keys: \(actionKeys)")
        }

        let actionKey = actionKeys[0]
        guard let actionValue = json[actionKey] as? JsonMap else {
            errors.append("\(actionKey) must be an object")
            return errors
        }

        switch actionKey {
        case "beginRendering":
            validateBeginRendering(actionValue, errors: &errors)
        case "surfaceUpdate":
            validateSurfaceUpdate(actionValue, errors: &errors)
        case "dataModelUpdate":
            validateDataModelUpdate(actionValue, errors: &errors)
        case "deleteSurface":
            validateDeleteSurface(actionValue, errors: &errors)
        default:
            break
        }

        return errors
    }

    /// Validates a batch of raw A2UI messages with cross-message reference checks (L2).
    public static func validateMessages(_ messages: [JsonMap]) -> [String] {
        var errors = [String]()

        for (i, msg) in messages.enumerated() {
            let msgErrors = validateMessage(msg)
            for e in msgErrors {
                errors.append("Message \(i): \(e)")
            }
        }

        errors.append(contentsOf: checkReferences(messages))
        return errors
    }

    // MARK: - L1 Per-Action Validators

    private static func validateBeginRendering(_ br: JsonMap, errors: inout [String]) {
        if !(br["surfaceId"] is String) {
            errors.append("beginRendering missing or invalid surfaceId")
        }
        if !(br["root"] is String) {
            errors.append("beginRendering missing or invalid root")
        }
    }

    private static func validateSurfaceUpdate(_ su: JsonMap, errors: inout [String]) {
        if !(su["surfaceId"] is String) {
            errors.append("surfaceUpdate missing or invalid surfaceId")
        }
        guard let components = su["components"] as? [Any] else {
            errors.append("surfaceUpdate missing or invalid components array")
            return
        }
        for (i, comp) in components.enumerated() {
            guard let compMap = comp as? JsonMap else {
                errors.append("surfaceUpdate.components[\(i)] is not an object")
                continue
            }
            validateComponent(compMap, index: i, errors: &errors)
        }
    }

    private static func validateComponent(_ comp: JsonMap, index: Int, errors: inout [String]) {
        if !(comp["id"] is String) {
            errors.append("Component \(index) missing or invalid id")
        }
        guard let wrapper = comp["component"] as? JsonMap else {
            errors.append("Component \(index) missing component wrapper")
            return
        }
        if wrapper.isEmpty {
            errors.append("Component \(index) has empty component wrapper")
            return
        }
        if wrapper.count > 1 {
            errors.append("Component \(index) has multiple type keys: \(Array(wrapper.keys))")
        }
        if let typeName = wrapper.keys.first, !knownComponentTypes.contains(typeName) {
            errors.append("Component \(index) has unknown type: \(typeName)")
        }
    }

    private static func validateDataModelUpdate(_ dmu: JsonMap, errors: inout [String]) {
        if !(dmu["surfaceId"] is String) {
            errors.append("dataModelUpdate missing or invalid surfaceId")
        }
        if !(dmu["contents"] is [Any]) && dmu["value"] == nil {
            errors.append("dataModelUpdate missing contents array or value")
        }
    }

    private static func validateDeleteSurface(_ ds: JsonMap, errors: inout [String]) {
        if !(ds["surfaceId"] is String) {
            errors.append("deleteSurface missing or invalid surfaceId")
        }
    }

    // MARK: - L2 Cross-Message Reference Checks

    private static func checkReferences(_ messages: [JsonMap]) -> [String] {
        var errors = [String]()
        var componentIds = Set<String>()
        var seenIds = Set<String>()

        for msg in messages {
            guard let su = msg["surfaceUpdate"] as? JsonMap,
                  let components = su["components"] as? [JsonMap] else { continue }
            for comp in components {
                guard let id = comp["id"] as? String else { continue }
                if seenIds.contains(id) {
                    errors.append("Duplicate component ID: \(id)")
                }
                seenIds.insert(id)
                componentIds.insert(id)
            }
        }

        for msg in messages {
            guard let br = msg["beginRendering"] as? JsonMap else { continue }
            if let root = br["root"] as? String, !componentIds.contains(root) {
                errors.append("beginRendering.root references missing component: \(root)")
            }
        }

        for msg in messages {
            guard let su = msg["surfaceUpdate"] as? JsonMap,
                  let components = su["components"] as? [JsonMap] else { continue }
            for comp in components {
                guard let wrapper = comp["component"] as? JsonMap else { continue }
                let parentId = comp["id"] as? String ?? "?"
                checkComponentChildRefs(wrapper, parentId: parentId, componentIds: componentIds, errors: &errors)
            }
        }

        return errors
    }

    private static func checkComponentChildRefs(
        _ wrapper: JsonMap,
        parentId: String,
        componentIds: Set<String>,
        errors: inout [String]
    ) {
        for (typeName, value) in wrapper {
            guard let props = value as? JsonMap else { continue }

            if let child = props["child"] as? String, !componentIds.contains(child) {
                errors.append("\(typeName).child in \"\(parentId)\" references missing component: \(child)")
            }

            for field in ["entryPointChild", "contentChild"] {
                if let ref = props[field] as? String, !componentIds.contains(ref) {
                    errors.append("\(typeName).\(field) in \"\(parentId)\" references missing component: \(ref)")
                }
            }

            if let children = props["children"] as? JsonMap {
                if let explicitList = children["explicitList"] as? [String] {
                    for cid in explicitList where !componentIds.contains(cid) {
                        errors.append("explicitList in \"\(parentId)\" references missing component: \(cid)")
                    }
                }
                if let template = children["template"] as? JsonMap,
                   let tid = template["componentId"] as? String,
                   !componentIds.contains(tid) {
                    errors.append("template.componentId in \"\(parentId)\" references missing component: \(tid)")
                }
            }

            if let tabItems = props["tabItems"] as? [JsonMap] {
                for (i, tab) in tabItems.enumerated() {
                    if let tabChild = tab["child"] as? String, !componentIds.contains(tabChild) {
                        errors.append("Tabs.tabItems[\(i)].child in \"\(parentId)\" references missing component: \(tabChild)")
                    }
                }
            }
        }
    }
}

/// Convenience function matching Dart's top-level `validateA2uiJson`.
public func validateA2uiJson(_ json: JsonMap) -> [String] {
    let errors = A2uiValidator.validateMessage(json)
    if !errors.isEmpty {
        NSLog("[A2uiValidator] Validation errors: \(errors.joined(separator: "; "))")
    }
    return errors
}
