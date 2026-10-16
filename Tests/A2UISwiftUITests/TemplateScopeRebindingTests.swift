// Copyright 2026 Advatar Systems AB
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import A2UISwiftCore
@testable import A2UISwiftUI

/// Uses the real message/tree/DataContext pipeline and the same action helper as
/// ButtonActionView. This is not hosted SwiftUI button activation or human input.
/// Run on the Apple SDK; Linux source-extracted probes do not qualify this suite.
@Suite("TemplateScopeRebinding", .serialized)
@MainActor
struct TemplateScopeRebindingTests {
    private let surfaceID = "synthetic-scope-regression"

    private func item(_ id: String) -> AnyCodable {
        .dictionary(["entityID": .string(id), "label": .string("Review " + id)])
    }

    private func makeViewModel(dictionary: Bool = false, nested: Bool = false) throws -> SurfaceViewModel {
        let vm = SurfaceViewModel(surface: SurfaceModel(id: surfaceID, catalog: Catalog(id: "scope-test")))
        try vm.processMessage(.createSurface(CreateSurfacePayload(surfaceId: surfaceID, catalogId: "scope-test")))
        let north: AnyCodable = dictionary
            ? .dictionary(["a": item("north-a"), "b": item("north-b")])
            : .array([item("north-a"), item("north-b")])
        let south: AnyCodable = dictionary
            ? .dictionary(["a": item("south-a"), "b": item("south-b")])
            : .array([item("south-a"), item("south-b")])
        let values: AnyCodable = nested
            ? .dictionary(["north": .array([.dictionary(["items": north])]),
                           "south": .array([.dictionary(["items": south])])])
            : .dictionary(["north": north, "south": south])
        try updateData(vm, path: "/", value: values)
        var components = [root(path: "/north", templateID: nested ? "group" : "row")]
        if nested {
            components.append(RawComponent(id: "group", component: "Column", properties: [
                "children": .dictionary(["componentId": .string("row"), "path": .string("items")])
            ]))
        }
        components += [
            RawComponent(id: "row", component: "Column", properties: [
                "children": .array([.string("button"), .string("modal")])
            ]),
            RawComponent(id: "button", component: "Button", properties: [
                "child": .string("label"),
                "action": .dictionary(["event": .dictionary([
                    "name": .string("synthetic.review"),
                    "context": .dictionary(["entityID": .dictionary(["path": .string("entityID")])])
                ])])
            ]),
            RawComponent(id: "label", component: "Text", properties: [
                "text": .dictionary(["path": .string("label")])
            ]),
            RawComponent(id: "modal", component: "Modal", properties: [
                "trigger": .string("trigger"), "content": .string("modalBody")
            ]),
            RawComponent(id: "trigger", component: "Text", properties: ["text": .string("Inspect")]),
            RawComponent(id: "modalBody", component: "Text", properties: ["text": .string("Synthetic detail")])
        ]
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(surfaceId: surfaceID, components: components)))
        return vm
    }

    private func root(path: String, templateID: String = "row", type: String = "Column") -> RawComponent {
        RawComponent(id: "root", component: type, properties: [
            "children": .dictionary(["componentId": .string(templateID), "path": .string(path)])
        ])
    }

    private func bind(_ vm: SurfaceViewModel, path: String, templateID: String = "row",
                      type: String = "Column") throws {
        try vm.processMessage(.updateComponents(UpdateComponentsPayload(
            surfaceId: surfaceID, components: [root(path: path, templateID: templateID, type: type)])))
    }

    private func updateData(_ vm: SurfaceViewModel, path: String, value: AnyCodable) throws {
        try vm.processMessage(.updateDataModel(UpdateDataModelPayload(surfaceId: surfaceID, path: path, value: value)))
    }

    private func descendants(_ vm: SurfaceViewModel, baseID: String) throws -> [ComponentNode] {
        let root = try #require(vm.componentTree)
        var result: [ComponentNode] = []
        func walk(_ node: ComponentNode) {
            if node.baseComponentId == baseID { result.append(node) }
            node.children.forEach(walk)
        }
        walk(root)
        return result
    }

    /// Resolve the actual label property and invoke the real button callback helper.
    /// Both protocol event publication and local host notification must happen once.
    private func expectAction(_ vm: SurfaceViewModel, button: ComponentNode, entity: String, path: String) throws {
        #expect(button.dataContextPath == path)
        let label = try #require(button.children.first)
        #expect(label.dataContextPath == path)
        let text = try label.typedProperties(TextProperties.self)
        let dc = vm.makeDataContext(path: label.dataContextPath)
        #expect(dc.resolve(text.text) == "Review " + entity)

        let props = try button.typedProperties(ButtonProperties.self)
        var emitted = 0
        let subscription = vm.onAction { _ in emitted += 1 }
        var local: [ResolvedAction] = []
        var triggers = 0
        a2uiHandleButtonAction(props.action, componentId: button.baseComponentId,
                               dataContext: vm.makeDataContext(path: button.dataContextPath),
                               surface: vm.surface, actionHandler: { local.append($0) },
                               onTriggerActivated: { triggers += 1 })
        withExtendedLifetime(subscription) {
            #expect(emitted == 1)
            #expect(triggers == 1)
            #expect(local.count == 1)
            #expect(local.first?.name == "synthetic.review")
            #expect(local.first?.sourceComponentId == "button")
            #expect(local.first?.context["entityID"] == .string(entity))
        }
    }

    @Test("equal-length arrays rebind labels, node scopes and action payloads")
    func sameLengthArray() throws {
        let vm = try makeViewModel()
        let rootBefore = try #require(vm.componentTree)
        let north = try descendants(vm, baseID: "button")
        #expect(north.count == 2)
        try expectAction(vm, button: north[0], entity: "north-a", path: "/north/0")
        try bind(vm, path: "/south")
        let south = try descendants(vm, baseID: "button")
        #expect(south.map(\.id) == north.map(\.id), "Wire/template IDs intentionally stay stable")
        #expect(vm.componentTree === rootBefore, "Unchanged root scope remains reusable")
        #expect(south.count == 2)
        #expect(south[0] !== north[0])
        try expectAction(vm, button: south[0], entity: "south-a", path: "/south/0")
        try expectAction(vm, button: south[1], entity: "south-b", path: "/south/1")
    }

    @Test("same dictionary keys do not retain the previous collection scope")
    func sameLengthDictionary() throws {
        let vm = try makeViewModel(dictionary: true)
        let before = try descendants(vm, baseID: "button")
        try bind(vm, path: "/south")
        let after = try descendants(vm, baseID: "button")
        #expect(after.map(\.id) == before.map(\.id))
        try expectAction(vm, button: after[0], entity: "south-a", path: "/south/a")
        try expectAction(vm, button: after[1], entity: "south-b", path: "/south/b")
    }

    @Test("nested equal-length templates rebind inherited descendant contexts")
    func nestedTemplates() throws {
        let vm = try makeViewModel(nested: true)
        let old = try descendants(vm, baseID: "button")
        try bind(vm, path: "/south", templateID: "group")
        let current = try descendants(vm, baseID: "button")
        #expect(current.map(\.id) == old.map(\.id))
        #expect(current[0] !== old[0])
        try expectAction(vm, button: current[0], entity: "south-a", path: "/south/0/items/0")
        try expectAction(vm, button: current[1], entity: "south-b", path: "/south/0/items/1")
    }

    @Test("repeated scope changes dispatch only from the current tree")
    func scopeRoundTrip() throws {
        let vm = try makeViewModel()
        let original = try #require(descendants(vm, baseID: "button").first)
        for scope in ["south", "north", "south", "north"] {
            try bind(vm, path: "/" + scope)
            let button = try #require(descendants(vm, baseID: "button").first)
            #expect(button !== original)
            try expectAction(vm, button: button, entity: scope + "-a", path: "/" + scope + "/0")
        }
    }

    @Test("same-scope data updates preserve nodes while resolving current values")
    func sameScopeUpdate() throws {
        let vm = try makeViewModel()
        let before = try #require(descendants(vm, baseID: "button").first)
        try updateData(vm, path: "/north", value: .array([item("updated-a"), item("updated-b")]))
        let after = try #require(descendants(vm, baseID: "button").first)
        #expect(after === before)
        try expectAction(vm, button: after, entity: "updated-a", path: "/north/0")
    }

    @Test("modal state stays within its resolved data scope")
    func scopedUIState() throws {
        let vm = try makeViewModel()
        let old = try #require(descendants(vm, baseID: "modal").first)
        let oldState = try #require(old.uiState as? ModalUIState)
        oldState.isPresented = true
        try bind(vm, path: "/north")
        let same = try #require(descendants(vm, baseID: "modal").first)
        #expect(same === old)
        #expect(same.uiState === oldState)
        try bind(vm, path: "/south")
        let current = try #require(descendants(vm, baseID: "modal").first)
        let fresh = try #require(current.uiState as? ModalUIState)
        #expect(current !== old)
        #expect(fresh !== oldState)
        #expect(!fresh.isPresented)
        try bind(vm, path: "/north")
        let returned = try #require(descendants(vm, baseID: "modal").first?.uiState as? ModalUIState)
        #expect(returned !== oldState)
        #expect(!returned.isPresented)
    }

    @Test("same-scope UI state survives a replacing ancestor type")
    func sameScopeMigration() throws {
        let vm = try makeViewModel()
        let old = try #require(descendants(vm, baseID: "modal").first?.uiState as? ModalUIState)
        old.isPresented = true
        let previousRoot = vm.componentTree
        try bind(vm, path: "/north", type: "Row")
        #expect(vm.componentTree !== previousRoot)
        let current = try #require(descendants(vm, baseID: "modal").first?.uiState as? ModalUIState)
        #expect(current === old)
        #expect(current.isPresented)
    }

    @Test("empty replacement collection does not revive former scope state")
    func delayedReplacementData() throws {
        let vm = try makeViewModel()
        let old = try #require(descendants(vm, baseID: "button").first)
        try updateData(vm, path: "/south", value: .array([]))
        try bind(vm, path: "/south")
        #expect(try descendants(vm, baseID: "button").isEmpty)
        try updateData(vm, path: "/south", value: .array([item("fresh-south")]))
        let current = try #require(descendants(vm, baseID: "button").first)
        #expect(current !== old)
        try expectAction(vm, button: current, entity: "fresh-south", path: "/south/0")
    }
}
