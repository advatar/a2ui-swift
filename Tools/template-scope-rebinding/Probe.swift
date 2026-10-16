#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// Minimal property-carrier fixtures for dependencies not executed in this probe.
// ComponentNode and UIState come byte-for-byte from the pinned real core sources.
public enum ComponentType: Equatable { case Column, Row, Button, Text, Modal, Tabs }
public struct A2UIAccessibility: Equatable {}
public struct RawComponent: Equatable {
    public var marker = "fixture"
    public func typedProperties<T: Decodable>(_ type: T.Type) throws -> T {
        throw ProbeError.unusedDecoder
    }
}
enum ProbeError: Error { case unusedDecoder }

@main
struct ScopeProbe {
    static func node(_ id: String, _ path: String, _ type: ComponentType = .Button,
                     _ children: [ComponentNode] = [], _ state: (any ComponentUIState)? = nil) -> ComponentNode {
        ComponentNode(id: id, baseComponentId: String(id.split(separator: ":")[0]),
                      type: type, dataContextPath: path, weight: nil,
                      instance: RawComponent(), children: children, uiState: state)
    }
    static func root(_ children: [ComponentNode], _ type: ComponentType = .Column) -> ComponentNode {
        node("root", "/", type, children)
    }
    static func main() {
        let r = ExtractedReconciler()
        var failures = 0
        var total = 0
        func check(_ id: String, _ condition: Bool, _ evidence: String = "") {
            total += 1
            if !condition { failures += 1 }
            print("\(condition ? "PASS" : "FAIL") \(id) \(evidence)")
        }
        // Same count, same production template IDs, different resolved collection path.
        do {
            let old = root((0..<2).map { node("button" + r.suffix("/", $0), "/north/\($0)") })
            let original = old.children[0]
            let new = root((0..<2).map { node("button" + r.suffix("/", $0), "/south/\($0)") })
            let result = r.rebuild(old, new)
            check("array_scope", result.children.map(\.dataContextPath) == ["/south/0", "/south/1"]
                  && result.children[0] !== original,
                  "actual=\(result.children.map(\.dataContextPath))")
        }
        // Isolate migration from reconciliation: a reconciliation-only fix is insufficient.
        do {
            let state = ModalUIState(); state.isPresented = true
            let old = root([node("modal:0", "/north/0", .Modal, [], state)])
            let fresh = ModalUIState()
            let incoming = root([node("modal:0", "/south/0", .Modal, [], fresh)])
            r.migrateOnly(old, incoming)
            check("migration_scope", incoming.children[0].uiState === fresh
                  && (incoming.children[0].uiState as? ModalUIState)?.isPresented == false)
        }
        do {
            let state = ModalUIState(); state.isPresented = true
            let child = node("modal:0", "/north/0", .Modal, [], state)
            let old = root([child])
            let incoming = root([node("modal:0", "/north/0", .Modal, [], ModalUIState())])
            let result = r.rebuild(old, incoming)
            check("same_scope", result === old && result.children[0] === child
                  && result.children[0].uiState === state && state.isPresented)
        }
        do {
            let state = TabsUIState(); state.selectedIndex = 2
            let old = root([node("tabs:0", "/north/0", .Tabs, [], state)])
            let incoming = root([node("tabs:0", "/north/0", .Tabs, [], TabsUIState())], .Row)
            let result = r.rebuild(old, incoming)
            check("same_scope_parent_replacement", result !== old
                  && result.children[0].uiState === state && state.selectedIndex == 2)
        }
        do {
            let initial = node("button:0", "/north/0")
            var current = root([initial])
            var valid = true
            for scope in ["south", "north", "south", "north"] {
                current = r.rebuild(current, root([node("button:0", "/\(scope)/0")]))
                valid = valid && current.children[0].dataContextPath == "/\(scope)/0"
                    && current.children[0] !== initial
            }
            check("round_trip", valid)
        }
        do {
            let old = root([node("button:entry", "/north/entry")])
            let result = r.rebuild(old, root([node("button:entry", "/south/entry")]))
            check("dictionary_scope", result.children[0].dataContextPath == "/south/entry")
        }
        do {
            let suffix = r.suffix("/groups/0", 0)
            let old = root([node("row" + suffix, "/groups/0/north/0", .Row,
                                 [node("button" + suffix, "/groups/0/north/0")])])
            let incoming = root([node("row" + suffix, "/groups/0/south/0", .Row,
                                      [node("button" + suffix, "/groups/0/south/0")])])
            let result = r.rebuild(old, incoming)
            check("nested_scope", suffix == ":0:0"
                  && result.children[0].children[0].dataContextPath == "/groups/0/south/0")
        }
        do {
            let a = ModalUIState(); a.isPresented = true
            let b = ModalUIState()
            let old = root([node("north", "/", .Column, [node("modal:0", "/north/0", .Modal, [], a)]),
                            node("south", "/", .Column, [node("modal:0", "/south/0", .Modal, [], b)])])
            let incoming = root([node("north", "/", .Column, [node("modal:0", "/north/0", .Modal, [], ModalUIState())]),
                                 node("south", "/", .Column, [node("modal:0", "/south/0", .Modal, [], ModalUIState())])])
            r.migrateOnly(old, incoming)
            check("parallel_scope_migration", incoming.children[0].children[0].uiState === a
                  && incoming.children[1].children[0].uiState === b)
        }
        do {
            let old = node("row:0", "/north/0", .Row)
            let incoming = node("row:0", "/north/0", .Row)
            incoming.instance.marker = "new same-scope properties"
            let result = r.rebuild(old, incoming)
            check("same_scope_property_refresh", result === old && result.instance == incoming.instance)
        }
        print("RESULT checks=\(total) failures=\(failures)")
        exit(failures == 0 ? 0 : 1)
    }
}
