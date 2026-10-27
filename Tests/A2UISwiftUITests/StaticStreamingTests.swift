// Copyright 2026 Advatar Systems AB
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing
@testable import A2UISwiftCore
@testable import A2UISwiftUI

@Suite("Static streaming", .serialized)
@MainActor
struct StaticStreamingTests {
    private let surfaceID = "static-streaming"

    private func model() throws -> SurfaceViewModel {
        let vm = SurfaceViewModel(catalog: basicCatalog)
        try vm.processMessage(.createSurface(.init(surfaceId: surfaceID, catalogId: basicCatalog.id)))
        return vm
    }

    private func send(_ vm: SurfaceViewModel, _ components: [RawComponent]) throws {
        try vm.processMessage(.updateComponents(.init(surfaceId: surfaceID, components: components)))
    }

    private func root(_ ids: [String], type: String = "Column") -> RawComponent {
        RawComponent(id: "root", component: type,
                     properties: ["children": .array(ids.map(AnyCodable.string))])
    }

    private func text(_ id: String, _ value: String? = nil) -> RawComponent {
        RawComponent(id: id, component: "Text", properties: ["text": .string(value ?? id)])
    }

    @Test("ordered, reverse and sparse arrivals immediately follow the declared order")
    func arrivalOrder() throws {
        for kind in ["Column", "Row", "List"] {
            for order in [[0, 1, 2, 3], [3, 2, 1, 0], [2, 0, 3, 1]] {
                let vm = try model()
                let ids = (0..<4).map { "leaf\($0)" }
                try send(vm, [root(ids, type: kind)])
                let parent = try #require(vm.componentTree)
                var present = Set<Int>()
                for index in order {
                    try send(vm, [text(ids[index])])
                    present.insert(index)
                    #expect(vm.componentTree === parent)
                    #expect(vm.incrementalLeafUpdateCount == present.count)
                    #expect(parent.children.map(\.id) == present.sorted().map { ids[$0] })
                    #expect(parent.children.allSatisfy { $0.dataContextPath == "/" })
                }
            }
        }
    }

    @Test("batch overwrite, metadata and leaf type replacement preserve immediate state")
    func leafChanges() throws {
        let vm = try model()
        try send(vm, [root(["a", "b"]), text("a"), text("b")])
        let parent = try #require(vm.componentTree)
        let a = parent.children[0], b = parent.children[1]
        let changed = RawComponent(id: "a", component: "Text", weight: 2,
                                   properties: ["text": .string("latest")])
        try send(vm, [text("a", "discarded"), changed, text("unreferenced")])
        #expect(parent.children[0] === a)
        #expect(parent.children[1] === b)
        #expect(a.instance == changed)
        #expect(a.weight == 2)
        try send(vm, [RawComponent(id: "a", component: "Icon", properties: ["name": .string("home")])])
        #expect(parent.children[0] !== a)
        #expect(parent.children[0].type == .Icon)
        #expect(parent.children[1] === b)
    }

    @Test("data binding and state stay current without changing static topology")
    func staticDataAndState() throws {
        let vm = try model()
        try send(vm, [root(["title", "choice"]),
                      RawComponent(id: "title", component: "Text", properties: [
                        "text": .dictionary(["path": .string("/title")])]),
                      RawComponent(id: "choice", component: "ChoicePicker")])
        let parent = try #require(vm.componentTree)
        let title = parent.children[0], choice = parent.children[1]
        let state = choice.uiState
        try vm.processMessage(.updateDataModel(.init(surfaceId: surfaceID, path: "/title", value: .string("new"))))
        #expect(vm.componentTree === parent)
        #expect(parent.children[0] === title)
        #expect(parent.children[1].uiState === state)
        let props = try title.typedProperties(TextProperties.self)
        #expect(vm.makeDataContext().resolve(props.text) == "new")
    }

    @Test("root changes, duplicates and complex children retain the full-tree behavior")
    func topologyChanges() throws {
        let vm = try model()
        try send(vm, [root(["a", "b"]), text("a"), text("b")])
        try send(vm, [root(["b", "a"])])
        #expect(vm.componentTree?.children.map(\.id) == ["b", "a"])
        try send(vm, [RawComponent(id: "a", component: "Card", properties: ["child": .string("inner")]), text("inner")])
        #expect(vm.componentTree?.children.last?.children.first?.id == "inner")
        try send(vm, [text("a", "flat again")])
        #expect(vm.componentTree?.children.last?.children.isEmpty == true)
        try send(vm, [root(["a", "a"])])
        #expect(vm.componentTree?.children.map(\.id) == ["a", "a"])
        try send(vm, [text("a", "both")])
        #expect(vm.componentTree?.children.allSatisfy { $0.instance.properties["text"] == .string("both") } == true)
        try send(vm, [root(["root", "a"])])
        #expect(vm.componentTree?.children.map(\.id) == ["a"])
        #expect(vm.incrementalLeafUpdateCount == 0, "structural batches must use the full rebuild")
    }

    @Test("template rebinding and late custom references remain visible after leaving the static path")
    func templatesAndCustom() throws {
        let vm = try model()
        try send(vm, [root(["a"]), text("a")])
        try vm.processMessage(.updateDataModel(.init(surfaceId: surfaceID, path: "/items",
                                                    value: .array([.string("first")]))))
        try send(vm, [RawComponent(id: "root", component: "Column", properties: [
            "children": .dictionary(["componentId": .string("a"), "path": .string("/items")])])])
        #expect(vm.componentTree?.children.first?.dataContextPath == "/items/0")
        try vm.processMessage(.updateDataModel(.init(surfaceId: surfaceID, path: "/items",
                                                    value: .array([.string("first"), .string("second")]))))
        #expect(vm.componentTree?.children.map(\.dataContextPath) == ["/items/0", "/items/1"])
        try send(vm, [RawComponent(id: "root", component: "CustomWidget", properties: ["detailId": .string("late")])])
        try send(vm, [text("late")])
        #expect(vm.componentTree?.children.first?.id == "late")
    }

    @Test("deletion resets static streaming state before the next surface")
    func deletion() throws {
        let vm = try model()
        try send(vm, [root(["a"]), text("a")])
        try vm.processMessage(.deleteSurface(.init(surfaceId: surfaceID)))
        #expect(vm.componentTree == nil)
        try vm.processMessage(.createSurface(.init(surfaceId: surfaceID, catalogId: basicCatalog.id)))
        try send(vm, [root(["b"]), text("b")])
        #expect(vm.componentTree?.children.map(\.id) == ["b"])
    }

    @Test("malformed container properties never gain children through incremental arrival")
    func malformedContainer() throws {
        let vm = try model()
        var invalid = root(["a"])
        invalid.properties["align"] = .number(42)
        try send(vm, [invalid])
        try send(vm, [text("a")])
        #expect(vm.componentTree?.children.isEmpty == true)
        #expect(vm.incrementalLeafUpdateCount == 0)
    }

    @Test("explicit tree reset or changed child count takes the rebuild path")
    func explicitTreeReset() throws {
        let vm = try model()
        try send(vm, [root(["a", "b"]), text("a"), text("b")])
        vm.componentTree?.children.removeLast()
        try send(vm, [text("b", "restored")])
        #expect(vm.componentTree?.children.map(\.id) == ["a", "b"])
        vm.componentTree = nil
        try send(vm, [text("a", "current")])
        #expect(vm.componentTree?.children.map(\.id) == ["a", "b"])
        vm.componentTree?.children.reverse() // same-count external mutation needs explicit repair
        vm.rebuildComponentTree()
        #expect(vm.componentTree?.children.map(\.id) == ["a", "b"])
        try send(vm, [text("b", "rebuilt")])
        #expect(vm.componentTree?.children.last?.instance.properties["text"] == .string("rebuilt"))
    }

    @Test("one batch combines sparse arrivals, updates and type replacement")
    func mixedBatch() throws {
        let vm = try model()
        try send(vm, [root(["a", "b", "c", "d"]), text("b"), text("d")])
        let parent = try #require(vm.componentTree)
        let b = parent.children[0], d = parent.children[1]
        try send(vm, [text("c"), text("b", "updated"),
                      RawComponent(id: "d", component: "Icon", properties: ["name": .string("home")]), text("a")])
        #expect(vm.incrementalLeafUpdateCount == 4)
        #expect(parent.children.map(\.id) == ["a", "b", "c", "d"])
        #expect(parent.children[1] === b)
        #expect(b.instance.properties["text"] == .string("updated"))
        #expect(parent.children[3] !== d)
        #expect(parent.children[3].type == .Icon)
    }

    @Test("clearing the public tree releases the node graph immediately")
    func releasesClearedTree() throws {
        let vm = try model()
        try send(vm, [root(["a"]), text("a")])
        weak var previous = vm.componentTree
        vm.componentTree = nil
        #expect(previous == nil, "the streaming index must not extend the rendered tree lifetime")
        try send(vm, [text("a", "rebuilt")])
        #expect(vm.componentTree?.children.first?.instance.properties["text"] == .string("rebuilt"))
    }
    private func button(_ id: String = "review", child: String = "caption", event: String = "preview") -> RawComponent {
        RawComponent(id: id, component: "Button", properties: ["child": .string(child),
                     "action": .dictionary(["event": .dictionary(["name": .string(event)])])])
    }

    @Test("static sibling arrivals preserve a complete terminal button and its caption")
    func terminalButtonSiblings() throws {
        for kind in ["Column", "Row", "List"] {
            let vm = try model(), ids = (0..<16).map { "leaf\($0)" }
            try send(vm, [root(["review"] + ids, type: kind), button(), RawComponent(id: "caption", component: "Text", properties: ["text": .dictionary(["path": .string("/caption")])])])
            let parent = try #require(vm.componentTree), control = parent.children[0], caption = control.children[0]
            let initial = vm.incrementalLeafUpdateCount
            for index in (0..<16).reversed() {
                try send(vm, [text(ids[index])])
                #expect(parent.children[0] === control)
                #expect(control.children[0] === caption)
                #expect(parent.children.map(\.id) == ["review"] + Array(ids[index...]))
            }
            #expect(vm.incrementalLeafUpdateCount == initial + ids.count)
            try vm.processMessage(.updateDataModel(.init(surfaceId: surfaceID, path: "/caption", value: .string("new"))))
            #expect(vm.componentTree === parent)
            #expect(control.children[0] === caption)
            let properties = try caption.typedProperties(TextProperties.self)
            #expect(vm.makeDataContext().resolve(properties.text) == "new")
        }
    }

    @Test("button and caption updates, including late replacement captions, rebuild immediately")
    func protectedButtonUpdates() throws {
        let vm = try model()
        try send(vm, [root(["review", "late"]), button()])
        try send(vm, [text("late")])
        #expect(vm.incrementalLeafUpdateCount == 0, "missing caption cannot engage static indexing")
        try send(vm, [text("caption", "first")])
        try send(vm, [text("late", "incremental")])
        #expect(vm.incrementalLeafUpdateCount == 1)
        try send(vm, [text("caption", "changed")])
        #expect(vm.componentTree?.children[0].children[0].instance.properties["text"] == .string("changed"))
        #expect(vm.incrementalLeafUpdateCount == 1)
        try send(vm, [button(event: "different-event")])
        let renderedButton = try #require(vm.componentTree?.children[0])
        let action = try renderedButton.typedProperties(ButtonProperties.self).action
        if case .event(let name, _) = action { #expect(name == "different-event") }
        else { Issue.record("button event was not replaced") }
        try send(vm, [button(child: "next-caption")])
        #expect(vm.componentTree?.children[0].children.isEmpty == true)
        try send(vm, [text("next-caption", "arrived")])
        #expect(vm.componentTree?.children[0].children[0].id == "next-caption")
        try send(vm, [text("late", "incremental again")])
        #expect(vm.incrementalLeafUpdateCount == 2)
        try send(vm, [text("caption", "unreferenced")])
        #expect(vm.componentTree?.children[0].children[0].id == "next-caption")
    }

    @Test("shared, nested or root-listed button captions keep full-tree semantics")
    func unsupportedButtonCaptions() throws {
        for shape in ["shared", "nested", "root-listed", "icon"] {
            let vm = try model()
            var parts = [root(["review", "late"] + (shape == "shared" ? ["second"] : shape == "root-listed" ? ["caption"] : [])), button(), text("caption")]
            if shape == "shared" { parts.append(button("second")) }
            if shape == "nested" {
                parts[2] = RawComponent(id: "caption", component: "Column", properties: ["children": .array([.string("inner")])])
                parts.append(text("inner"))
            }
            if shape == "icon" { parts[2] = RawComponent(id: "caption", component: "Icon", properties: ["name": .string("home")]) }
            try send(vm, parts)
            try send(vm, [text("late")])
            #expect(vm.incrementalLeafUpdateCount == 0)
            #expect(vm.componentTree?.children[0].children[0].id == "caption")
            try send(vm, [text("caption", "new leaf")])
            #expect(vm.componentTree?.children[0].children[0].instance.properties["text"] == .string("new leaf"))
        }
    }

    @Test("terminal controls do not extend a cleared tree lifetime")
    func terminalButtonLifetime() throws {
        let vm = try model()
        try send(vm, [root(["review"]), button(), text("caption")])
        weak var previous = vm.componentTree
        weak var control = vm.componentTree?.children.first
        weak var caption = control?.children.first
        vm.componentTree = nil
        #expect(previous == nil)
        #expect(control == nil)
        #expect(caption == nil)
    }

}
