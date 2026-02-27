import Testing
import Foundation
@testable import A2UI

// MARK: - Version Detection

@Suite("Version Detection")
struct VersionDetectionTests {

    @Test func v09MessageParsesNormally() throws {
        let json = try parseJSON(#"{"version": "v0.9", "createSurface": {"surfaceId": "s1", "catalogId": "com.google.genui.basic"}}"#)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .createSurface(let p) = msg else {
            Issue.record("Expected createSurface"); return
        }
        #expect(p.surfaceId == "s1")
        #expect(p.catalogId == "com.google.genui.basic")
    }

    @Test func v08MessageWithoutVersionParses() throws {
        let json = try parseJSON(#"{"beginRendering": {"surfaceId": "s1", "root": "root"}}"#)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .createSurface(let p) = msg else {
            Issue.record("Expected createSurface"); return
        }
        #expect(p.surfaceId == "s1")
    }

    @Test func unsupportedVersionThrows() throws {
        let json = try parseJSON(#"{"version": "v0.7", "createSurface": {"surfaceId": "s1", "catalogId": "c"}}"#)
        #expect(throws: A2UIValidationError.self) {
            _ = try A2UIMessage.fromJSON(json)
        }
    }

    @Test func unknownFormatThrows() throws {
        let json = try parseJSON(#"{"unknownKey": {"surfaceId": "s1"}}"#)
        #expect(throws: A2UIValidationError.self) {
            _ = try A2UIMessage.fromJSON(json)
        }
    }

    @Test func isV08MessageDetection() throws {
        let v08 = try parseJSON(#"{"beginRendering": {"surfaceId": "s1"}}"#)
        let v09 = try parseJSON(#"{"version": "v0.9", "createSurface": {"surfaceId": "s1"}}"#)
        let unknown = try parseJSON(#"{"foo": "bar"}"#)

        #expect(A2UIMessageV08Adapter.isV08Message(v08) == true)
        #expect(A2UIMessageV08Adapter.isV08Message(v09) == false)
        #expect(A2UIMessageV08Adapter.isV08Message(unknown) == false)
    }
}

// MARK: - Message Type Mapping

@Suite("Message Type Mapping")
struct MessageTypeMappingTests {

    @Test func beginRenderingConvertsToCreateSurface() throws {
        let json = try parseJSON("""
            {"beginRendering": {"surfaceId": "main", "root": "my-root", "styles": {"primaryColor": "#FF0000"}}}
        """)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .createSurface(let p) = msg else {
            Issue.record("Expected createSurface"); return
        }
        #expect(p.surfaceId == "main")
        #expect(p.rootComponentId == "my-root")
        #expect((p.theme?["primaryColor"] as? String) == "#FF0000")
    }

    @Test func surfaceUpdateConvertsToUpdateComponents() throws {
        let json = try parseJSON("""
            {"surfaceUpdate": {"surfaceId": "main", "components": [
                {"id": "t1", "component": {"Text": {"text": {"literalString": "Hello"}}}}
            ]}}
        """)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .updateComponents(let p) = msg else {
            Issue.record("Expected updateComponents"); return
        }
        #expect(p.surfaceId == "main")
        #expect(p.components.count == 1)
        #expect(p.components[0].type == "Text")
    }

    @Test func dataModelUpdateConvertsToUpdateDataModel() throws {
        let json = try parseJSON("""
            {"dataModelUpdate": {"surfaceId": "main", "path": "/user", "contents": [
                {"key": "name", "valueString": "Alice"}
            ]}}
        """)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .updateDataModel(let p) = msg else {
            Issue.record("Expected updateDataModel"); return
        }
        #expect(p.surfaceId == "main")
        #expect(p.path.description == "/user")
        let val = p.value as? JsonMap
        #expect((val?["name"] as? String) == "Alice")
    }

    @Test func deleteSurfaceWorksInBothVersions() throws {
        let v08 = try parseJSON(#"{"deleteSurface": {"surfaceId": "s1"}}"#)
        let v09 = try parseJSON(#"{"version": "v0.9", "deleteSurface": {"surfaceId": "s2"}}"#)

        let msg1 = try A2UIMessage.fromJSON(v08)
        let msg2 = try A2UIMessage.fromJSON(v09)

        guard case .deleteSurface(let sid1) = msg1 else { Issue.record("Expected deleteSurface"); return }
        guard case .deleteSurface(let sid2) = msg2 else { Issue.record("Expected deleteSurface"); return }
        #expect(sid1 == "s1")
        #expect(sid2 == "s2")
    }
}

// MARK: - beginRendering Details

@Suite("beginRendering Details")
struct BeginRenderingDetailTests {

    @Test func stylesConvertToTheme() throws {
        let json = try parseJSON("""
            {"beginRendering": {"surfaceId": "s1", "root": "root", "styles": {"primaryColor": "#0000FF", "borderRadius": 8}}}
        """)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .createSurface(let p) = msg else { Issue.record("Expected createSurface"); return }
        #expect((p.theme?["primaryColor"] as? String) == "#0000FF")
        #expect((p.theme?["borderRadius"] as? Int) == 8)
    }

    @Test func rootComponentId() throws {
        let json = try parseJSON("""
            {"beginRendering": {"surfaceId": "s1", "root": "my-custom-root"}}
        """)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .createSurface(let p) = msg else { Issue.record("Expected createSurface"); return }
        #expect(p.rootComponentId == "my-custom-root")
    }

    @Test func defaultCatalogId() throws {
        let json = try parseJSON("""
            {"beginRendering": {"surfaceId": "s1", "root": "root"}}
        """)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .createSurface(let p) = msg else { Issue.record("Expected createSurface"); return }
        #expect(p.catalogId == basicCatalogId)
    }

    @Test func explicitCatalogId() throws {
        let json = try parseJSON("""
            {"beginRendering": {"surfaceId": "s1", "root": "root", "catalogId": "custom.catalog"}}
        """)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .createSurface(let p) = msg else { Issue.record("Expected createSurface"); return }
        #expect(p.catalogId == "custom.catalog")
    }

    @Test func missingSurfaceIdThrows() throws {
        let json = try parseJSON(#"{"beginRendering": {"root": "root"}}"#)
        #expect(throws: A2UIValidationError.self) {
            _ = try A2UIMessage.fromJSON(json)
        }
    }
}

// MARK: - Component Format Conversion

@Suite("Component Format Conversion")
struct ComponentFormatTests {

    @Test func nestedComponentConvertsToFlat() throws {
        let json = try parseJSON("""
            {"id": "t1", "component": {"Text": {"text": {"literalString": "Hello"}, "usageHint": "h2"}}}
        """)
        let comp = try A2UIMessageV08Adapter.convertComponent(json)
        #expect(comp.id == "t1")
        #expect(comp.type == "Text")
        #expect((comp.properties["text"] as? String) == "Hello")
        #expect((comp.properties["variant"] as? String) == "h2")
    }

    @Test func v09FlatComponentStillWorks() throws {
        let json = try parseJSON("""
            {"id": "t1", "component": "Text", "text": "Hello", "variant": "h2"}
        """)
        let comp = try A2UIMessageV08Adapter.convertComponent(json)
        #expect(comp.id == "t1")
        #expect(comp.type == "Text")
        #expect((comp.properties["text"] as? String) == "Hello")
        #expect((comp.properties["variant"] as? String) == "h2")
    }

    @Test func multipleComponentsConverted() throws {
        let json = try parseJSON("""
            {"surfaceUpdate": {"surfaceId": "s1", "components": [
                {"id": "col", "component": {"Column": {"children": {"explicitList": ["t1", "t2"]}}}},
                {"id": "t1", "component": {"Text": {"text": {"literalString": "First"}}}},
                {"id": "t2", "component": {"Text": {"text": {"literalString": "Second"}}}}
            ]}}
        """)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .updateComponents(let p) = msg else { Issue.record("Expected updateComponents"); return }
        #expect(p.components.count == 3)
        #expect(p.components[0].type == "Column")
        #expect(p.components[1].type == "Text")
        #expect((p.components[0].properties["children"] as? [String]) == ["t1", "t2"])
    }

    @Test func componentMissingIdThrows() throws {
        let json = try parseJSON("""
            {"component": {"Text": {"text": {"literalString": "Hi"}}}}
        """)
        #expect(throws: A2UIValidationError.self) {
            _ = try A2UIMessageV08Adapter.convertComponent(json)
        }
    }

    @Test func componentMissingComponentFieldThrows() throws {
        let json = try parseJSON(#"{"id": "t1"}"#)
        #expect(throws: A2UIValidationError.self) {
            _ = try A2UIMessageV08Adapter.convertComponent(json)
        }
    }
}

// MARK: - BoundValue Conversion

@Suite("BoundValue Conversion")
struct BoundValueTests {

    @Test func literalStringConverted() {
        let result = A2UIMessageV08Adapter.convertBoundValue(["literalString": "Hello"])
        #expect((result as? String) == "Hello")
    }

    @Test func literalNumberConverted() {
        let result = A2UIMessageV08Adapter.convertBoundValue(["literalNumber": 42])
        #expect((result as? Int) == 42)
    }

    @Test func literalBooleanConverted() {
        let result = A2UIMessageV08Adapter.convertBoundValue(["literalBoolean": true])
        #expect((result as? Bool) == true)
    }

    @Test func pathPreserved() {
        let result = A2UIMessageV08Adapter.convertBoundValue(["path": "/user/name"])
        let map = result as? JsonMap
        #expect((map?["path"] as? String) == "/user/name")
    }

    @Test func pathWithLiteralKeepsPath() {
        let result = A2UIMessageV08Adapter.convertBoundValue([
            "path": "/user/name",
            "literalString": "default"
        ])
        let map = result as? JsonMap
        #expect((map?["path"] as? String) == "/user/name")
        #expect(map?["literalString"] == nil)
    }
}

// MARK: - Children Conversion

@Suite("Children Conversion")
struct ChildrenConversionTests {

    @Test func explicitListConverted() {
        let result = A2UIMessageV08Adapter.convertChildren(["explicitList": ["a", "b", "c"]])
        #expect((result as? [String]) == ["a", "b", "c"])
    }

    @Test func templateChildrenConverted() {
        let input: JsonMap = [
            "template": ["componentId": "card", "dataBinding": "/items"] as JsonMap
        ]
        let result = A2UIMessageV08Adapter.convertChildren(input) as? JsonMap
        #expect((result?["componentId"] as? String) == "card")
        #expect((result?["path"] as? String) == "/items")
    }

    @Test func directArrayChildrenPreserved() {
        let result = A2UIMessageV08Adapter.convertChildren(["x", "y"])
        #expect((result as? [String]) == ["x", "y"])
    }
}

// MARK: - Property Name Remapping

@Suite("Property Name Remapping")
struct PropertyRemappingTests {

    @Test func usageHintToVariant() {
        let result = A2UIMessageV08Adapter.remapPropertyNames(["usageHint": "h2", "text": "Hello"])
        #expect((result["variant"] as? String) == "h2")
        #expect(result["usageHint"] == nil)
        #expect((result["text"] as? String) == "Hello")
    }

    @Test func distributionToJustify() {
        let result = A2UIMessageV08Adapter.remapPropertyNames(["distribution": "spaceBetween"])
        #expect((result["justify"] as? String) == "spaceBetween")
    }

    @Test func alignmentToAlign() {
        let result = A2UIMessageV08Adapter.remapPropertyNames(["alignment": "center"])
        #expect((result["align"] as? String) == "center")
    }
}

// MARK: - Data Model Conversion

@Suite("Data Model Conversion")
struct DataModelConversionTests {

    @Test func contentsAdjacencyListConverted() {
        let contents: [JsonMap] = [
            ["key": "name", "valueString": "Alice"],
            ["key": "age", "valueNumber": 30],
            ["key": "active", "valueBoolean": true]
        ]
        let result = A2UIMessageV08Adapter.convertContentsToValue(contents)
        #expect((result["name"] as? String) == "Alice")
        #expect((result["age"] as? Int) == 30)
        #expect((result["active"] as? Bool) == true)
    }

    @Test func nestedValueMapConverted() {
        let contents: [JsonMap] = [
            ["key": "address", "valueMap": [
                ["key": "street", "valueString": "123 Main St"],
                ["key": "city", "valueString": "Anytown"]
            ] as [JsonMap]]
        ]
        let result = A2UIMessageV08Adapter.convertContentsToValue(contents)
        let address = result["address"] as? JsonMap
        #expect((address?["street"] as? String) == "123 Main St")
        #expect((address?["city"] as? String) == "Anytown")
    }

    @Test func mixedTypesInContents() {
        let contents: [JsonMap] = [
            ["key": "str", "valueString": "text"],
            ["key": "num", "valueNumber": 3.14],
            ["key": "bool", "valueBoolean": false],
            ["key": "nested", "valueMap": [
                ["key": "inner", "valueString": "deep"]
            ] as [JsonMap]]
        ]
        let result = A2UIMessageV08Adapter.convertContentsToValue(contents)
        #expect((result["str"] as? String) == "text")
        #expect(result["num"] != nil)
        #expect((result["bool"] as? Bool) == false)
        let nested = result["nested"] as? JsonMap
        #expect((nested?["inner"] as? String) == "deep")
    }

    @Test func directValuePreserved() throws {
        let json = try parseJSON("""
            {"dataModelUpdate": {"surfaceId": "s1", "path": "/count", "value": 42}}
        """)
        let msg = try A2UIMessage.fromJSON(json)
        guard case .updateDataModel(let p) = msg else { Issue.record("Expected updateDataModel"); return }
        #expect((p.value as? Int) == 42)
    }

    @Test func dataModelMissingSurfaceIdThrows() throws {
        let json = try parseJSON("""
            {"dataModelUpdate": {"path": "/", "contents": []}}
        """)
        #expect(throws: A2UIValidationError.self) {
            _ = try A2UIMessage.fromJSON(json)
        }
    }
}

// MARK: - Action Conversion

@Suite("Action Conversion")
struct ActionConversionTests {

    @Test func actionContextArrayConverted() {
        let action: Any = [
            "name": "submit",
            "context": [
                ["key": "id", "value": ["literalString": "123"]],
                ["key": "formId", "value": ["literalString": "f-1"]]
            ]
        ] as JsonMap
        let result = A2UIMessageV08Adapter.convertAction(action) as? JsonMap
        let event = result?["event"] as? JsonMap
        #expect((event?["name"] as? String) == "submit")
        let ctx = event?["context"] as? JsonMap
        #expect((ctx?["id"] as? String) == "123")
        #expect((ctx?["formId"] as? String) == "f-1")
    }
}

// MARK: - SurfaceDefinition Root Support

@Suite("SurfaceDefinition Root Support")
struct SurfaceDefinitionRootTests {

    @Test func defaultRootComponentId() {
        let def = SurfaceDefinition(surfaceId: "test")
        #expect(def.rootComponentId == "root")
    }

    @Test func customRootComponentId() {
        let def = SurfaceDefinition(surfaceId: "test", rootComponentId: "my-root")
        #expect(def.rootComponentId == "my-root")
        let copy = def.copy(rootComponentId: "another-root")
        #expect(copy.rootComponentId == "another-root")
    }
}

// MARK: - End-to-End Tests

@Suite("End-to-End Engine Processing")
struct EndToEndTests {

    @Test func v08StreamRendersViaEngine() throws {
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

        #expect(controller.registry.hasSurface(id: "test"))
        let def = controller.registry.getSurface(id: "test")
        #expect(def?.components.count == 2)
        #expect(def?.components["t1"]?.type == "Text")
        #expect((def?.components["t1"]?.properties["text"] as? String) == "Hello v0.8!")
        #expect((def?.components["t1"]?.properties["variant"] as? String) == "h2")
    }

    @Test func v08StreamWithDataBinding() throws {
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
        #expect((name as? String) == "Alice")
    }

    @Test func mixedV08AndV09Messages() throws {
        let catalog = BasicCatalog.create()
        let controller = SurfaceController(catalogs: [catalog])
        defer { controller.dispose() }

        let v08Create = try parseJSON("""
            {"beginRendering": {"surfaceId": "mixed", "root": "root"}}
        """)
        controller.handleMessage(try A2UIMessage.fromJSON(v08Create))

        let v09Update = try parseJSON("""
            {"version": "v0.9", "updateComponents": {"surfaceId": "mixed", "components": [
                {"id": "root", "component": "Column", "children": ["greeting"]},
                {"id": "greeting", "component": "Text", "text": "Mixed versions!", "variant": "h3"}
            ]}}
        """)
        controller.handleMessage(try A2UIMessage.fromJSON(v09Update))

        #expect(controller.registry.hasSurface(id: "mixed"))
        let def = controller.registry.getSurface(id: "mixed")
        #expect(def?.components.count == 2)
        #expect((def?.components["greeting"]?.properties["text"] as? String) == "Mixed versions!")
    }
}

// MARK: - Stream Parser

@Suite("Stream Parser Compatibility")
struct StreamParserTests {

    @Test func streamParserHandlesV08Messages() {
        let parser = A2UIStreamParser()

        let v08Json = """
        {"beginRendering": {"surfaceId": "stream-test", "root": "root"}}
        {"surfaceUpdate": {"surfaceId": "stream-test", "components": [
            {"id": "root", "component": {"Text": {"text": {"literalString": "Streamed!"}}}}
        ]}}
        """

        let messages = parser.addChunk(v08Json)
        #expect(messages.count == 2)
        guard case .createSurface(let p) = messages[0] else {
            Issue.record("Expected createSurface"); return
        }
        #expect(p.surfaceId == "stream-test")
        guard case .updateComponents(let u) = messages[1] else {
            Issue.record("Expected updateComponents"); return
        }
        #expect(u.components[0].type == "Text")
    }
}

// MARK: - Helpers

private func parseJSON(_ jsonString: String) throws -> JsonMap {
    let data = jsonString.data(using: .utf8)!
    return try JSONSerialization.jsonObject(with: data) as! JsonMap
}

private func parseJSONArray(_ jsonString: String) throws -> [JsonMap] {
    let data = jsonString.data(using: .utf8)!
    return try JSONSerialization.jsonObject(with: data) as! [JsonMap]
}
