import UIKit
import A2UI

/// Comprehensive test suite for A2UI v0.8 protocol compatibility.
///
/// Verifies that all v0.8 message formats are correctly converted to
/// internal v0.9 model and rendered by the engine.
class V08CompatibilityTestVC: UITableViewController {

    struct TestResult {
        let name: String
        let passed: Bool
        let detail: String
    }

    private var results: [TestResult] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        results = Self.runAllTests()
        tableView.reloadData()
    }

    /// Runs all tests and returns results. Can be called without UI.
    static func runAllTests() -> [TestResult] {
        let runner = V08CompatibilityTestVC()
        return runner._runAllTests()
    }

    /// Runs all tests, prints results to console, returns (passed, total).
    @discardableResult
    static func runAndLogTests() -> (passed: Int, total: Int) {
        let results = runAllTests()
        let passed = results.filter { $0.passed }.count
        NSLog("[V08Test] ========== v0.8 Compatibility Tests ==========")
        for r in results {
            NSLog("[V08Test] %@ %@: %@", r.passed ? "PASS" : "FAIL", r.name, r.detail)
        }
        NSLog("[V08Test] ========== Results: %d/%d passed ==========", passed, results.count)
        return (passed, results.count)
    }

    private func _runAllTests() -> [TestResult] {
        var results: [TestResult] = []

        // Version Detection
        results.append(testV09MessageParsesNormally())
        results.append(testV08MessageWithoutVersionParses())
        results.append(testUnsupportedVersionThrows())
        results.append(testUnknownFormatThrows())
        results.append(testIsV08MessageDetection())

        // Message Type Mapping
        results.append(testBeginRenderingConvertsToCreateSurface())
        results.append(testSurfaceUpdateConvertsToUpdateComponents())
        results.append(testDataModelUpdateConvertsToUpdateDataModel())
        results.append(testDeleteSurfaceWorksInBothVersions())

        // beginRendering Details
        results.append(testBeginRenderingStylesConvertToTheme())
        results.append(testBeginRenderingRootComponentId())
        results.append(testBeginRenderingDefaultCatalogId())
        results.append(testBeginRenderingExplicitCatalogId())
        results.append(testBeginRenderingMissingSurfaceIdThrows())

        // Component Format Conversion
        results.append(testNestedComponentConvertsToFlat())
        results.append(testV09FlatComponentStillWorks())
        results.append(testMultipleComponentsConverted())
        results.append(testComponentMissingIdThrows())
        results.append(testComponentMissingComponentFieldThrows())

        // BoundValue Conversion
        results.append(testLiteralStringConverted())
        results.append(testLiteralNumberConverted())
        results.append(testLiteralBooleanConverted())
        results.append(testPathPreserved())
        results.append(testPathWithLiteralKeepsPath())

        // Children Conversion
        results.append(testExplicitListConverted())
        results.append(testTemplateChildrenConverted())
        results.append(testDirectArrayChildrenPreserved())

        // Property Name Remapping
        results.append(testUsageHintToVariant())
        results.append(testDistributionToJustify())
        results.append(testAlignmentToAlign())

        // Data Model Conversion
        results.append(testContentsAdjacencyListConverted())
        results.append(testNestedValueMapConverted())
        results.append(testMixedTypesInContents())
        results.append(testDirectValuePreserved())
        results.append(testDataModelMissingSurfaceIdThrows())

        // Action Conversion
        results.append(testActionContextArrayConverted())

        // SurfaceDefinition Root Support
        results.append(testSurfaceDefinitionDefaultRoot())
        results.append(testSurfaceDefinitionCustomRoot())

        // End-to-End: Full Engine Processing
        results.append(testEndToEndV08Stream())
        results.append(testEndToEndV08WithDataBinding())
        results.append(testEndToEndMixedVersions())

        // Stream Parser Compatibility
        results.append(testStreamParserV08Messages())

        return results
    }

    // MARK: - Table View

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let result = results[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = "\(result.passed ? "✅" : "❌") \(result.name)"
        content.secondaryText = result.detail
        content.secondaryTextProperties.numberOfLines = 0
        content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let passed = results.filter { $0.passed }.count
        return "Results: \(passed)/\(results.count) passed"
    }

    // MARK: - Helper

    private func test(_ name: String, _ block: () throws -> String) -> TestResult {
        do {
            let detail = try block()
            return TestResult(name: name, passed: true, detail: detail)
        } catch {
            return TestResult(name: name, passed: false, detail: "ERROR: \(error.localizedDescription)")
        }
    }

    private func parseJSON(_ jsonString: String) throws -> JsonMap {
        let data = jsonString.data(using: .utf8)!
        return try JSONSerialization.jsonObject(with: data) as! JsonMap
    }

    private func parseJSONArray(_ jsonString: String) throws -> [JsonMap] {
        let data = jsonString.data(using: .utf8)!
        return try JSONSerialization.jsonObject(with: data) as! [JsonMap]
    }

    // MARK: - Version Detection Tests

    private func testV09MessageParsesNormally() -> TestResult {
        test("v0.9 message parses normally") {
            let json = try parseJSON("""
                {"version": "v0.9", "createSurface": {"surfaceId": "s1", "catalogId": "com.google.genui.basic"}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .createSurface(let p) = msg else { throw TestError("Expected createSurface") }
            try assert(p.surfaceId == "s1", "surfaceId mismatch")
            return "surfaceId=s1, catalogId=\(p.catalogId)"
        }
    }

    private func testV08MessageWithoutVersionParses() -> TestResult {
        test("v0.8 message without version parses") {
            let json = try parseJSON("""
                {"beginRendering": {"surfaceId": "s1", "root": "root"}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .createSurface(let p) = msg else { throw TestError("Expected createSurface") }
            try assert(p.surfaceId == "s1", "surfaceId mismatch")
            return "v0.8 beginRendering -> createSurface OK"
        }
    }

    private func testUnsupportedVersionThrows() -> TestResult {
        test("unsupported version throws") {
            let json = try parseJSON("""
                {"version": "v0.7", "createSurface": {"surfaceId": "s1", "catalogId": "c"}}
            """)
            do {
                _ = try A2UIMessage.fromJSON(json)
                throw TestError("Should have thrown")
            } catch let e as A2UIValidationError {
                try assert(e.message.contains("Unsupported"), "Error message should mention unsupported")
                return "Correctly rejected version v0.7: \(e.message)"
            }
        }
    }

    private func testUnknownFormatThrows() -> TestResult {
        test("unknown format throws") {
            let json = try parseJSON("""
                {"unknownKey": {"surfaceId": "s1"}}
            """)
            do {
                _ = try A2UIMessage.fromJSON(json)
                throw TestError("Should have thrown")
            } catch let e as A2UIValidationError {
                try assert(e.message.contains("Unknown"), "Should mention unknown format")
                return "Correctly rejected: \(e.message)"
            }
        }
    }

    private func testIsV08MessageDetection() -> TestResult {
        test("isV08Message detection") {
            let v08 = try parseJSON(#"{"beginRendering": {"surfaceId": "s1"}}"#)
            let v09 = try parseJSON(#"{"version": "v0.9", "createSurface": {"surfaceId": "s1"}}"#)
            let unknown = try parseJSON(#"{"foo": "bar"}"#)

            try assert(A2UIMessageV08Adapter.isV08Message(v08) == true, "Should detect v0.8")
            try assert(A2UIMessageV08Adapter.isV08Message(v09) == false, "Should not detect v0.9 as v0.8")
            try assert(A2UIMessageV08Adapter.isV08Message(unknown) == false, "Should not detect unknown")
            return "v0.8=true, v0.9=false, unknown=false"
        }
    }

    // MARK: - Message Type Mapping Tests

    private func testBeginRenderingConvertsToCreateSurface() -> TestResult {
        test("beginRendering -> createSurface") {
            let json = try parseJSON("""
                {"beginRendering": {"surfaceId": "main", "root": "my-root", "styles": {"primaryColor": "#FF0000"}}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .createSurface(let p) = msg else { throw TestError("Expected createSurface") }
            try assert(p.surfaceId == "main", "surfaceId")
            try assert(p.rootComponentId == "my-root", "rootComponentId")
            try assert((p.theme?["primaryColor"] as? String) == "#FF0000", "theme.primaryColor")
            return "surfaceId=main, root=my-root, theme.primaryColor=#FF0000"
        }
    }

    private func testSurfaceUpdateConvertsToUpdateComponents() -> TestResult {
        test("surfaceUpdate -> updateComponents") {
            let json = try parseJSON("""
                {"surfaceUpdate": {"surfaceId": "main", "components": [
                    {"id": "t1", "component": {"Text": {"text": {"literalString": "Hello"}}}}
                ]}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .updateComponents(let p) = msg else { throw TestError("Expected updateComponents") }
            try assert(p.surfaceId == "main", "surfaceId")
            try assert(p.components.count == 1, "component count")
            try assert(p.components[0].type == "Text", "component type")
            return "1 component, type=Text"
        }
    }

    private func testDataModelUpdateConvertsToUpdateDataModel() -> TestResult {
        test("dataModelUpdate -> updateDataModel") {
            let json = try parseJSON("""
                {"dataModelUpdate": {"surfaceId": "main", "path": "/user", "contents": [
                    {"key": "name", "valueString": "Alice"}
                ]}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .updateDataModel(let p) = msg else { throw TestError("Expected updateDataModel") }
            try assert(p.surfaceId == "main", "surfaceId")
            try assert(p.path.description == "/user", "path")
            let val = p.value as? JsonMap
            try assert((val?["name"] as? String) == "Alice", "value.name")
            return "path=/user, value.name=Alice"
        }
    }

    private func testDeleteSurfaceWorksInBothVersions() -> TestResult {
        test("deleteSurface works in both versions") {
            let v08 = try parseJSON(#"{"deleteSurface": {"surfaceId": "s1"}}"#)
            let v09 = try parseJSON(#"{"version": "v0.9", "deleteSurface": {"surfaceId": "s2"}}"#)

            let msg1 = try A2UIMessage.fromJSON(v08)
            let msg2 = try A2UIMessage.fromJSON(v09)

            guard case .deleteSurface(let sid1) = msg1 else { throw TestError("Expected deleteSurface") }
            guard case .deleteSurface(let sid2) = msg2 else { throw TestError("Expected deleteSurface") }
            try assert(sid1 == "s1", "v0.8 surfaceId")
            try assert(sid2 == "s2", "v0.9 surfaceId")
            return "v0.8=s1, v0.9=s2"
        }
    }

    // MARK: - beginRendering Detail Tests

    private func testBeginRenderingStylesConvertToTheme() -> TestResult {
        test("beginRendering.styles -> theme") {
            let json = try parseJSON("""
                {"beginRendering": {"surfaceId": "s1", "root": "root", "styles": {"primaryColor": "#0000FF", "borderRadius": 8}}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .createSurface(let p) = msg else { throw TestError("Expected createSurface") }
            try assert((p.theme?["primaryColor"] as? String) == "#0000FF", "primaryColor")
            try assert((p.theme?["borderRadius"] as? Int) == 8, "borderRadius")
            return "theme has primaryColor and borderRadius"
        }
    }

    private func testBeginRenderingRootComponentId() -> TestResult {
        test("beginRendering.root -> rootComponentId") {
            let json = try parseJSON("""
                {"beginRendering": {"surfaceId": "s1", "root": "my-custom-root"}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .createSurface(let p) = msg else { throw TestError("Expected createSurface") }
            try assert(p.rootComponentId == "my-custom-root", "rootComponentId")
            return "rootComponentId=my-custom-root"
        }
    }

    private func testBeginRenderingDefaultCatalogId() -> TestResult {
        test("beginRendering without catalogId gets default") {
            let json = try parseJSON("""
                {"beginRendering": {"surfaceId": "s1", "root": "root"}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .createSurface(let p) = msg else { throw TestError("Expected createSurface") }
            try assert(p.catalogId == basicCatalogId, "catalogId should be default")
            return "catalogId=\(p.catalogId)"
        }
    }

    private func testBeginRenderingExplicitCatalogId() -> TestResult {
        test("beginRendering with explicit catalogId") {
            let json = try parseJSON("""
                {"beginRendering": {"surfaceId": "s1", "root": "root", "catalogId": "custom.catalog"}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .createSurface(let p) = msg else { throw TestError("Expected createSurface") }
            try assert(p.catalogId == "custom.catalog", "catalogId")
            return "catalogId=custom.catalog"
        }
    }

    private func testBeginRenderingMissingSurfaceIdThrows() -> TestResult {
        test("beginRendering missing surfaceId throws") {
            let json = try parseJSON(#"{"beginRendering": {"root": "root"}}"#)
            do {
                _ = try A2UIMessage.fromJSON(json)
                throw TestError("Should have thrown")
            } catch let e as A2UIValidationError {
                try assert(e.message.contains("surfaceId"), "Should mention surfaceId")
                return "Correctly throws: \(e.message)"
            }
        }
    }

    // MARK: - Component Format Conversion Tests

    private func testNestedComponentConvertsToFlat() -> TestResult {
        test("nested component -> flat discriminator") {
            let json = try parseJSON("""
                {"id": "t1", "component": {"Text": {"text": {"literalString": "Hello"}, "usageHint": "h2"}}}
            """)
            let comp = try A2UIMessageV08Adapter.convertComponent(json)
            try assert(comp.id == "t1", "id")
            try assert(comp.type == "Text", "type")
            try assert((comp.properties["text"] as? String) == "Hello", "text should be literal string")
            try assert((comp.properties["variant"] as? String) == "h2", "usageHint -> variant")
            return "id=t1, type=Text, text=Hello, variant=h2"
        }
    }

    private func testV09FlatComponentStillWorks() -> TestResult {
        test("v0.9 flat component passes through") {
            let json = try parseJSON("""
                {"id": "t1", "component": "Text", "text": "Hello", "variant": "h2"}
            """)
            let comp = try A2UIMessageV08Adapter.convertComponent(json)
            try assert(comp.id == "t1", "id")
            try assert(comp.type == "Text", "type")
            try assert((comp.properties["text"] as? String) == "Hello", "text")
            try assert((comp.properties["variant"] as? String) == "h2", "variant")
            return "id=t1, type=Text, text=Hello, variant=h2"
        }
    }

    private func testMultipleComponentsConverted() -> TestResult {
        test("multiple v0.8 components converted") {
            let json = try parseJSON("""
                {"surfaceUpdate": {"surfaceId": "s1", "components": [
                    {"id": "col", "component": {"Column": {"children": {"explicitList": ["t1", "t2"]}}}},
                    {"id": "t1", "component": {"Text": {"text": {"literalString": "First"}}}},
                    {"id": "t2", "component": {"Text": {"text": {"literalString": "Second"}}}}
                ]}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .updateComponents(let p) = msg else { throw TestError("Expected updateComponents") }
            try assert(p.components.count == 3, "3 components")
            try assert(p.components[0].type == "Column", "first is Column")
            try assert(p.components[1].type == "Text", "second is Text")
            let children = p.components[0].properties["children"]
            try assert((children as? [String]) == ["t1", "t2"], "children converted to array")
            return "3 components: Column, Text, Text"
        }
    }

    private func testComponentMissingIdThrows() -> TestResult {
        test("component missing id throws") {
            let json = try parseJSON("""
                {"component": {"Text": {"text": {"literalString": "Hi"}}}}
            """)
            do {
                _ = try A2UIMessageV08Adapter.convertComponent(json)
                throw TestError("Should have thrown")
            } catch let e as A2UIValidationError {
                try assert(e.message.contains("id"), "Should mention id")
                return "Correctly throws: \(e.message)"
            }
        }
    }

    private func testComponentMissingComponentFieldThrows() -> TestResult {
        test("component missing component field throws") {
            let json = try parseJSON(#"{"id": "t1"}"#)
            do {
                _ = try A2UIMessageV08Adapter.convertComponent(json)
                throw TestError("Should have thrown")
            } catch let e as A2UIValidationError {
                try assert(e.message.contains("component"), "Should mention component")
                return "Correctly throws: \(e.message)"
            }
        }
    }

    // MARK: - BoundValue Conversion Tests

    private func testLiteralStringConverted() -> TestResult {
        test("literalString -> plain string") {
            let result = A2UIMessageV08Adapter.convertBoundValue(["literalString": "Hello"])
            try assert((result as? String) == "Hello", "Should be plain string")
            return "\"Hello\""
        }
    }

    private func testLiteralNumberConverted() -> TestResult {
        test("literalNumber -> plain number") {
            let result = A2UIMessageV08Adapter.convertBoundValue(["literalNumber": 42])
            try assert((result as? Int) == 42, "Should be plain number")
            return "42"
        }
    }

    private func testLiteralBooleanConverted() -> TestResult {
        test("literalBoolean -> plain bool") {
            let result = A2UIMessageV08Adapter.convertBoundValue(["literalBoolean": true])
            try assert((result as? Bool) == true, "Should be plain bool")
            return "true"
        }
    }

    private func testPathPreserved() -> TestResult {
        test("path binding preserved") {
            let result = A2UIMessageV08Adapter.convertBoundValue(["path": "/user/name"])
            let map = result as? JsonMap
            try assert((map?["path"] as? String) == "/user/name", "Should preserve path")
            return "{path: /user/name}"
        }
    }

    private func testPathWithLiteralKeepsPath() -> TestResult {
        test("path + literalString keeps path only") {
            let result = A2UIMessageV08Adapter.convertBoundValue([
                "path": "/user/name",
                "literalString": "default"
            ])
            let map = result as? JsonMap
            try assert((map?["path"] as? String) == "/user/name", "Should keep path")
            try assert(map?["literalString"] == nil, "Should drop literalString")
            return "{path: /user/name} (literal dropped)"
        }
    }

    // MARK: - Children Conversion Tests

    private func testExplicitListConverted() -> TestResult {
        test("explicitList -> array") {
            let result = A2UIMessageV08Adapter.convertChildren(["explicitList": ["a", "b", "c"]])
            try assert((result as? [String]) == ["a", "b", "c"], "Should be plain array")
            return "[a, b, c]"
        }
    }

    private func testTemplateChildrenConverted() -> TestResult {
        test("template with dataBinding -> path") {
            let input: JsonMap = [
                "template": ["componentId": "card", "dataBinding": "/items"] as JsonMap
            ]
            let result = A2UIMessageV08Adapter.convertChildren(input) as? JsonMap
            try assert((result?["componentId"] as? String) == "card", "componentId")
            try assert((result?["path"] as? String) == "/items", "dataBinding -> path")
            return "{componentId: card, path: /items}"
        }
    }

    private func testDirectArrayChildrenPreserved() -> TestResult {
        test("direct array children preserved") {
            let result = A2UIMessageV08Adapter.convertChildren(["x", "y"])
            try assert((result as? [String]) == ["x", "y"], "Should preserve array")
            return "[x, y]"
        }
    }

    // MARK: - Property Name Remapping Tests

    private func testUsageHintToVariant() -> TestResult {
        test("usageHint -> variant") {
            let result = A2UIMessageV08Adapter.remapPropertyNames(["usageHint": "h2", "text": "Hello"])
            try assert((result["variant"] as? String) == "h2", "usageHint -> variant")
            try assert(result["usageHint"] == nil, "usageHint should be removed")
            try assert((result["text"] as? String) == "Hello", "other props preserved")
            return "variant=h2, text=Hello"
        }
    }

    private func testDistributionToJustify() -> TestResult {
        test("distribution -> justify") {
            let result = A2UIMessageV08Adapter.remapPropertyNames(["distribution": "spaceBetween"])
            try assert((result["justify"] as? String) == "spaceBetween", "distribution -> justify")
            return "justify=spaceBetween"
        }
    }

    private func testAlignmentToAlign() -> TestResult {
        test("alignment -> align") {
            let result = A2UIMessageV08Adapter.remapPropertyNames(["alignment": "center"])
            try assert((result["align"] as? String) == "center", "alignment -> align")
            return "align=center"
        }
    }

    // MARK: - Data Model Conversion Tests

    private func testContentsAdjacencyListConverted() -> TestResult {
        test("contents adjacency list -> JSON object") {
            let contents: [JsonMap] = [
                ["key": "name", "valueString": "Alice"],
                ["key": "age", "valueNumber": 30],
                ["key": "active", "valueBoolean": true]
            ]
            let result = A2UIMessageV08Adapter.convertContentsToValue(contents)
            try assert((result["name"] as? String) == "Alice", "name")
            try assert((result["age"] as? Int) == 30, "age")
            try assert((result["active"] as? Bool) == true, "active")
            return "{name: Alice, age: 30, active: true}"
        }
    }

    private func testNestedValueMapConverted() -> TestResult {
        test("nested valueMap recursively converted") {
            let contents: [JsonMap] = [
                ["key": "address", "valueMap": [
                    ["key": "street", "valueString": "123 Main St"],
                    ["key": "city", "valueString": "Anytown"]
                ] as [JsonMap]]
            ]
            let result = A2UIMessageV08Adapter.convertContentsToValue(contents)
            let address = result["address"] as? JsonMap
            try assert((address?["street"] as? String) == "123 Main St", "street")
            try assert((address?["city"] as? String) == "Anytown", "city")
            return "{address: {street: 123 Main St, city: Anytown}}"
        }
    }

    private func testMixedTypesInContents() -> TestResult {
        test("mixed types in contents") {
            let contents: [JsonMap] = [
                ["key": "str", "valueString": "text"],
                ["key": "num", "valueNumber": 3.14],
                ["key": "bool", "valueBoolean": false],
                ["key": "nested", "valueMap": [
                    ["key": "inner", "valueString": "deep"]
                ] as [JsonMap]]
            ]
            let result = A2UIMessageV08Adapter.convertContentsToValue(contents)
            try assert((result["str"] as? String) == "text", "str")
            try assert(result["num"] != nil, "num exists")
            try assert((result["bool"] as? Bool) == false, "bool")
            let nested = result["nested"] as? JsonMap
            try assert((nested?["inner"] as? String) == "deep", "nested.inner")
            return "4 keys with mixed types"
        }
    }

    private func testDirectValuePreserved() -> TestResult {
        test("direct value (no contents) preserved") {
            let json = try parseJSON("""
                {"dataModelUpdate": {"surfaceId": "s1", "path": "/count", "value": 42}}
            """)
            let msg = try A2UIMessage.fromJSON(json)
            guard case .updateDataModel(let p) = msg else { throw TestError("Expected updateDataModel") }
            try assert((p.value as? Int) == 42, "value should be 42")
            return "value=42"
        }
    }

    private func testDataModelMissingSurfaceIdThrows() -> TestResult {
        test("dataModelUpdate missing surfaceId throws") {
            let json = try parseJSON("""
                {"dataModelUpdate": {"path": "/", "contents": []}}
            """)
            do {
                _ = try A2UIMessage.fromJSON(json)
                throw TestError("Should have thrown")
            } catch let e as A2UIValidationError {
                try assert(e.message.contains("surfaceId"), "Should mention surfaceId")
                return "Correctly throws: \(e.message)"
            }
        }
    }

    // MARK: - Action Conversion Tests

    private func testActionContextArrayConverted() -> TestResult {
        test("action context array -> map") {
            let action: Any = [
                "name": "submit",
                "context": [
                    ["key": "id", "value": ["literalString": "123"]],
                    ["key": "formId", "value": ["literalString": "f-1"]]
                ]
            ] as JsonMap
            let result = A2UIMessageV08Adapter.convertAction(action) as? JsonMap
            let event = result?["event"] as? JsonMap
            try assert((event?["name"] as? String) == "submit", "action name")
            let ctx = event?["context"] as? JsonMap
            try assert((ctx?["id"] as? String) == "123", "context.id")
            try assert((ctx?["formId"] as? String) == "f-1", "context.formId")
            return "event.name=submit, context={id: 123, formId: f-1}"
        }
    }

    // MARK: - SurfaceDefinition Root Tests

    private func testSurfaceDefinitionDefaultRoot() -> TestResult {
        test("SurfaceDefinition default rootComponentId") {
            let def = SurfaceDefinition(surfaceId: "test")
            try assert(def.rootComponentId == "root", "default is 'root'")
            return "rootComponentId=root"
        }
    }

    private func testSurfaceDefinitionCustomRoot() -> TestResult {
        test("SurfaceDefinition custom rootComponentId") {
            let def = SurfaceDefinition(surfaceId: "test", rootComponentId: "my-root")
            try assert(def.rootComponentId == "my-root", "custom root")
            let copy = def.copy(rootComponentId: "another-root")
            try assert(copy.rootComponentId == "another-root", "copied root")
            return "rootComponentId=my-root, copy=another-root"
        }
    }

    // MARK: - End-to-End Tests

    private func testEndToEndV08Stream() -> TestResult {
        test("e2e: v0.8 stream renders via engine") {
            let catalog = BasicCatalog.create()
            let controller = SurfaceController(catalogs: [catalog])
            defer { controller.dispose() }

            let messages = try parseJSONArray("""
            [
                {"beginRendering": {"surfaceId": "test", "root": "root"}},
                {"surfaceUpdate": {"surfaceId": "test", "components": [
                    {"id": "root", "component": {"Column": {"children": {"explicitList": ["t1"]}}}},
                    {"id": "t1", "component": {"Text": {"text": {"literalString": "Hello v0.8!"}, "usageHint": "h2"}}}
                ]}}
            ]
            """)

            for jsonObj in messages {
                let msg = try A2UIMessage.fromJSON(jsonObj)
                controller.handleMessage(msg)
            }

            try assert(controller.registry.hasSurface(id: "test"), "Surface should exist")
            let def = controller.registry.getSurface(id: "test")
            try assert(def?.components.count == 2, "2 components")
            try assert(def?.components["t1"]?.type == "Text", "t1 is Text")
            try assert((def?.components["t1"]?.properties["text"] as? String) == "Hello v0.8!", "text content")
            try assert((def?.components["t1"]?.properties["variant"] as? String) == "h2", "variant")
            return "Surface 'test' with 2 components, text='Hello v0.8!'"
        }
    }

    private func testEndToEndV08WithDataBinding() -> TestResult {
        test("e2e: v0.8 stream with data model") {
            let catalog = BasicCatalog.create()
            let controller = SurfaceController(catalogs: [catalog])
            defer { controller.dispose() }

            let messages = try parseJSONArray("""
            [
                {"beginRendering": {"surfaceId": "test", "root": "root"}},
                {"surfaceUpdate": {"surfaceId": "test", "components": [
                    {"id": "root", "component": {"Column": {"children": {"explicitList": ["name"]}}}},
                    {"id": "name", "component": {"Text": {"text": {"path": "/user/name"}}}}
                ]}},
                {"dataModelUpdate": {"surfaceId": "test", "path": "/", "contents": [
                    {"key": "user", "valueMap": [
                        {"key": "name", "valueString": "Alice"}
                    ]}
                ]}}
            ]
            """)

            for jsonObj in messages {
                let msg = try A2UIMessage.fromJSON(jsonObj)
                controller.handleMessage(msg)
            }

            let model = controller.store.getDataModel(surfaceId: "test")
            let name = model.getValue(path: DataPath("/user/name"))
            try assert((name as? String) == "Alice", "data model should have user.name=Alice")
            return "Data model: user.name=Alice"
        }
    }

    private func testEndToEndMixedVersions() -> TestResult {
        test("e2e: mixed v0.8 and v0.9 messages") {
            let catalog = BasicCatalog.create()
            let controller = SurfaceController(catalogs: [catalog])
            defer { controller.dispose() }

            let v08Create = try parseJSON("""
                {"beginRendering": {"surfaceId": "mixed", "root": "root"}}
            """)
            let msg1 = try A2UIMessage.fromJSON(v08Create)
            controller.handleMessage(msg1)

            let v09Update = try parseJSON("""
                {"version": "v0.9", "updateComponents": {"surfaceId": "mixed", "components": [
                    {"id": "root", "component": "Column", "children": ["greeting"]},
                    {"id": "greeting", "component": "Text", "text": "Mixed versions!", "variant": "h3"}
                ]}}
            """)
            let msg2 = try A2UIMessage.fromJSON(v09Update)
            controller.handleMessage(msg2)

            try assert(controller.registry.hasSurface(id: "mixed"), "Surface should exist")
            let def = controller.registry.getSurface(id: "mixed")
            try assert(def?.components.count == 2, "2 components")
            try assert((def?.components["greeting"]?.properties["text"] as? String) == "Mixed versions!", "text")
            return "v0.8 create + v0.9 update = works"
        }
    }

    // MARK: - Stream Parser Tests

    private func testStreamParserV08Messages() -> TestResult {
        test("stream parser handles v0.8 messages") {
            let parser = A2UIStreamParser()

            let v08Json = """
            {"beginRendering": {"surfaceId": "stream-test", "root": "root"}}
            {"surfaceUpdate": {"surfaceId": "stream-test", "components": [
                {"id": "root", "component": {"Text": {"text": {"literalString": "Streamed!"}}}}
            ]}}
            """

            let messages = parser.addChunk(v08Json)
            try assert(messages.count == 2, "Should parse 2 messages, got \(messages.count)")
            guard case .createSurface(let p) = messages[0] else { throw TestError("Expected createSurface") }
            try assert(p.surfaceId == "stream-test", "surfaceId")
            guard case .updateComponents(let u) = messages[1] else { throw TestError("Expected updateComponents") }
            try assert(u.components[0].type == "Text", "component type")
            return "2 messages parsed from stream: createSurface + updateComponents"
        }
    }
}

// MARK: - Test Error

private struct TestError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private func assert(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw TestError("Assertion failed: \(message)")
    }
}
