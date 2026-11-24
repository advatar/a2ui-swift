@testable import A2UISwiftCore
import Testing
import Foundation

/// Event contexts that carry a plain JSON object, as the ProvidEHR gateway's
/// `resolve_intent` buttons do (`"params": {}` and paging params with a nested
/// binding). Previously these hit a debug `assertionFailure` and, in release,
/// became an empty string, losing the object and any bindings inside it.
@Suite("Action context objects")
struct ActionContextObjectTests {

    private func decodeAction(_ json: String) throws -> Action {
        try JSONDecoder().decode(Action.self, from: Data(json.utf8))
    }

    private func context(_ action: Action) -> [String: DynamicValue] {
        guard case .event(_, let ctx) = action, let ctx else { return [:] }
        return ctx
    }

    // Exact action from a live gateway `command_center` surface (home-choose-patient).
    private let emptyParams = #"{"event":{"context":{"ehrId":"","intent":"patient_registry","params":{}},"name":"resolve_intent"}}"#

    // Shape of the gateway's operation-catalog paging buttons.
    private let pagingParams = #"{"event":{"name":"resolve_intent","context":{"intent":"api_operation_catalog","params":{"query":{"path":"/catalog/query"},"offset":30}}}}"#

    @Test("decodes an empty object as an object, not a string")
    func decodesEmptyObject() throws {
        let ctx = context(try decodeAction(emptyParams))
        guard case .object(let params)? = ctx["params"] else {
            Issue.record("params was \(String(describing: ctx["params"]))")
            return
        }
        #expect(params.isEmpty)
        guard case .string("patient_registry")? = ctx["intent"] else {
            Issue.record("intent was \(String(describing: ctx["intent"]))")
            return
        }
    }

    @Test("the non-throwing AnyCodable initializer resolves the same as the Decodable one")
    func anyCodableInitializerMatches() throws {
        let raw = try JSONDecoder().decode(AnyCodable.self, from: Data(pagingParams.utf8))
        let viaAnyCodable = Action(from: raw)
        guard case .object(let params)? = context(viaAnyCodable)["params"],
              case .dataBinding(path: "/catalog/query")?? = params["query"] else {
            Issue.record("params did not decode as an object with a nested binding")
            return
        }
        let ctx = createTestDataContext(data: ["catalog": .dictionary(["query": .string("x")])], path: "/")
        #expect(ctx.resolveAction(viaAnyCodable) == ctx.resolveAction(try decodeAction(pagingParams)))
    }

    @Test("resolves bindings nested inside an object when the action is resolved")
    func resolvesNestedBindings() throws {
        let ctx = createTestDataContext(data: ["catalog": .dictionary(["query": .string("care plan")])], path: "/")
        let resolved = ctx.resolveAction(try decodeAction(pagingParams))
        let expected: AnyCodable = .dictionary(["event": .dictionary([
            "name": .string("resolve_intent"),
            "context": .dictionary([
                "intent": .string("api_operation_catalog"),
                "params": .dictionary(["query": .string("care plan"), "offset": .number(30)]),
            ]),
        ])])
        #expect(resolved == expected)
    }

    @Test("an unset nested binding resolves to null, keeping the key")
    func unsetNestedBindingIsNull() throws {
        let ctx = createTestDataContext(data: [:], path: "/")
        #expect(ctx.resolveDynamicValue(.object(["query": .dataBinding(path: "/missing")]))
                == .dictionary(["query": .null]))
    }

    @Test("a null member stays null through decoding, resolution and encoding")
    func nullMemberIsPreserved() throws {
        let json = #"{"event":{"name":"resolve_intent","context":{"intent":"patient_registry","params":{"subject_id":null,"offset":0}}}}"#
        let action = try decodeAction(json)
        let ctx = createTestDataContext(data: [:], path: "/")
        guard case .dictionary(let root) = ctx.resolveAction(action),
              case .dictionary(let event)? = root["event"],
              case .dictionary(let values)? = event["context"] else {
            Issue.record("unexpected shape")
            return
        }
        #expect(values["params"] == .dictionary(["subject_id": .null, "offset": .number(0)]))
        let reencoded = try JSONDecoder().decode(AnyCodable.self, from: try JSONEncoder().encode(action))
        #expect(reencoded == (try JSONDecoder().decode(AnyCodable.self, from: Data(json.utf8))))
    }

    @Test("bindings two objects deep resolve")
    func deeplyNestedBindingsResolve() throws {
        let json = #"{"event":{"name":"e","context":{"params":{"filter":{"name":{"path":"/name"},"page":2}}}}}"#
        let ctx = createTestDataContext(data: ["name": .string("Ada")], path: "/")
        guard case .dictionary(let root) = ctx.resolveAction(try decodeAction(json)),
              case .dictionary(let event)? = root["event"],
              case .dictionary(let values)? = event["context"] else {
            Issue.record("unexpected shape")
            return
        }
        #expect(values["params"] == .dictionary(["filter": .dictionary(["name": .string("Ada"), "page": .number(2)])]))
    }

    @Test("arrays inside an object stay literal, as arrays do elsewhere")
    func arraysInsideObjectsStayLiteral() throws {
        let json = #"{"event":{"name":"e","context":{"params":{"ids":["a","b"]}}}}"#
        let ctx = createTestDataContext(data: [:], path: "/")
        guard case .dictionary(let root) = ctx.resolveAction(try decodeAction(json)),
              case .dictionary(let event)? = root["event"],
              case .dictionary(let values)? = event["context"] else {
            Issue.record("unexpected shape")
            return
        }
        #expect(values["params"] == .dictionary(["ids": .array([.string("a"), .string("b")])]))
    }

    @Test("an empty object resolves to an empty object")
    func emptyObjectResolves() throws {
        let ctx = createTestDataContext(data: [:], path: "/")
        let resolved = ctx.resolveAction(try decodeAction(emptyParams))
        guard case .dictionary(let root) = resolved,
              case .dictionary(let event)? = root["event"],
              case .dictionary(let values)? = event["context"] else {
            Issue.record("unexpected shape \(resolved)")
            return
        }
        #expect(values["params"] == .dictionary([:]))
        #expect(values["ehrId"] == .string(""))
    }

    @Test("objects round-trip through encoding, including nested bindings")
    func roundTrips() throws {
        let original = try decodeAction(pagingParams)
        let encoded = try JSONEncoder().encode(original)
        let again = try JSONDecoder().decode(AnyCodable.self, from: encoded)
        let source = try JSONDecoder().decode(AnyCodable.self, from: Data(pagingParams.utf8))
        #expect(again == source)
    }

    @Test("path and call objects keep their existing meaning")
    func bindingsAndCallsUnchanged() {
        guard case .dataBinding(path: "/a") = DynamicValue(from: .dictionary(["path": .string("/a")])) else {
            Issue.record("path object is no longer a binding")
            return
        }
        guard case .functionCall(let call) = DynamicValue(from: .dictionary(["call": .string("now")])) else {
            Issue.record("call object is no longer a function call")
            return
        }
        #expect(call.call == "now")
    }
}
