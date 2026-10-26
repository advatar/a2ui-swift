# Template scope rebinding — 2026-10-16

Tracking: [UniversalInteractionKit #100](https://github.com/advatar/UniversalInteractionKit/issues/100).

## Result and limits

The exact pinned fork retains the wrong data-context path when equal-length template collections rebind. This is reproduced by executing its source-extracted reconciliation methods with its real `ComponentNode` and `UIState` definitions. The same probe separately demonstrates unscoped UI-state migration. The repair changes one production file: node reuse now requires equal resolved data-context paths, and UI-state migration keys include that path. Existing template/wire IDs and same-scope reuse are preserved.

**This is not yet a native renderer qualification.** Eight real `SurfaceViewModel`/message/DataContext/button-action-helper tests have been added, but Apple compilation and execution of those tests are NOT_RUN here. Hosted SwiftUI button activation, real input and shared consumer validation also remain NOT_RUN. Do not change the UniversalA2UI pin or merge this repair on the portable probe alone.

The October 15 [upstream fix #3202](https://github.com/a2ui-project/a2ui/commit/7c61659591791b17f6698a9c6a2ea1e986a0b4df) changes a newer ResolvedAction architecture. This older fork instead has immutable ComponentNode.dataContextPath plus ID/type-only reconciliation. This is a targeted repair of the mechanism actually present, not a blind cherry-pick or a claim of identical upstream code.

## History

- Pinned baseline: `57d42442df7d1c786a54357fd1cbe8c8371f4b54`.
- Plan-before-code: `6e895e30c7427e949fcbf2b43f472e4702ddc0b1`.
- Native tests on the unchanged baseline: `a79e6c149b7ad3cd923e67587f2dfa87541ef1e2` (tests added, native execution NOT_RUN).
- Production repair: `fa3fb4e0cb625b165f1764bb630e31f35b3bc549`.
- Branch: `fix/template-scope-rebinding-100`, based exactly on the consumer pin. Existing fork branches and consumer manifests were not changed.

## Executed here

Environment: Swift 6.2.1 (`swift-6.2.1-RELEASE`), x86_64 Linux; Python 3.13. No Apple SDK is available in this executor. Direct container GitHub networking failed; connector reads supplied source text, reconstructed bytes were verified against the repository Git blob identities before execution.

| Gate | Observed result |
|---|---|
| Original source, `-Onone` | 9 checks executed: 6 desired-correctness regressions fail, 3 same-scope controls pass |
| Original source, `-O` | Same 6 failures and 3 passes |
| Repaired source, `-Onone` | 9/9 pass |
| Repaired source, `-O` | 9/9 pass |
| Restore missing node-path guard | Compiles; 4 scope regressions fail at `-Onone` |
| Restore ID-only UI-state migration | Compiles; 2 migration regressions fail at `-Onone` |
| Wrong source-pin negative control | Refused before extraction or compilation |
| Native regression source `swiftc -frontend -parse` | Syntax PASS only; no Apple import resolution/type checking/execution |
| Python probe syntax | PASS |

Mutation runs stop at the first optimization failure: `-O` mutation execution is NOT_RUN. Baseline regression failure is expected detection, not a passing renderer suite. Raw successful baseline/repair probe logs are beside this file. No expected outcomes were weakened after observing the defect.

The first dynamic-runtime probe failed to link the installed Linux Observation library (`swift::threading::fatal` undefined). Final runs use the installed **static** Swift runtime (`-static-stdlib`), retaining the actual Observation-backed node/state sources. No production source or runtime was replaced with a no-op. The final static commands completed without diagnostic warnings. This workaround does not qualify an Apple runtime.

## Probe scope

The script extracts `templateSuffix`, `reconcileNode`, `reconcileChildren`, `collectUIStates`, `migrateUIStates`, and the repaired UIStateKey declaration from the selected production source. Those method bodies are not reimplemented. It uses byte-identical production ComponentNode/UIState files. A small orchestrating wrapper feeds explicit old/new trees to those methods. ComponentType, RawComponent and accessibility are minimal carrier fixtures; their property decoding is deliberately unimplemented and unused.

Therefore the probe demonstrates **tree/state reuse behavior**, not wire parsing, catalog admission, DataContext resolution, SwiftUI diffing, native input or action dispatch. The native tests are intended to cover the real message → template expansion → current label → `a2uiHandleButtonAction` path. Even a native helper-test pass is not a hosted button click. All data is synthetic North/South entities; no network callback or executor exists in the fixtures.

Covered probes: equal-count arrays; dictionary-key reuse; nested scopes; repeated switching; isolated state migration; same-scope node/state preservation; ancestor replacement; simultaneous identical positional IDs in distinct scopes; same-scope property refresh.

This does not introduce generic stale-event authorization: a deliberately retained old callback must still be refused by the host's context/connection/revision boundary. Same path with newly replaced domain identity likewise remains a host identity/admission concern. The repair must not be described as clinical or end-to-end authorization qualification.

## Reproduce the source probe

From this branch in a complete local fork checkout, using a new output path:

```sh
python3 Tools/template-scope-rebinding/probe.py \
  --root . \
  --expected-source-blob 2d5fa39f6f4abc1a878253232922ff063c242954 \
  --output /tmp/a2ui-scope-probe-patched-unique \
  --expect pass --static-stdlib
```

The static flag is for the Linux toolchain used here; omit it on Apple. For baseline, use a detached checkout of the pinned commit as `--root`, retain this branch's probe script, use expected source blob `adee4798559b964f31fbc14feb5bcb6b09a55d51`, a separate output directory and `--expect regression`. The script verifies both real core file pins as well. Do not overwrite another developer's worktree or an existing evidence directory.

## Mac gate — required before promotion

Use two isolated worktrees, one at tests-only commit `a79e6c149b7ad3cd923e67587f2dfa87541ef1e2` and one at this repair's final head. Read local AGENTS/current owner guidance. Record exact HEAD, OS, Xcode, Swift and SDKs; preserve all shared settings, simulators, test sessions and existing permissions.

In each checkout run serially, with separate scratch paths:

```sh
swift test --filter TemplateScopeRebindingTests --jobs 2
swift test -c release --filter TemplateScopeRebindingTests --jobs 2
```

Expected before/after: the unchanged original must actually compile and fail the wrong-scope/state assertions; the repaired source must compile and pass all eight native tests. A compiler failure does not count as reproducing the bug. The fixtures exercise equal-length arrays/dictionaries, nested scope changes, repeated changes, same-path values, scoped modal state, replacing ancestors and data arriving after an empty replacement collection. They call the actual label resolver and actual button action helper, checking protocol publication and exact local payload.

Then add or run a bounded hosted SwiftUI activation check using the pinned renderer: retain item count and IDs while switching North/South repeatedly; activate the **currently visible** button; assert visible label, admitted scope and proposed entity agree. Run without clinical data or actual provider actions. Distinguish API helper calls, dispatched native events, AX automation and human input. Capture only verified sample windows; do not alter permissions or take over another user's input.

Run the full relevant renderer/core suites and actual UniversalA2UI consumer gates on an isolated candidate dependency override. Review existing renderer catalog/override callbacks as part of that native check. Do not edit production manifests, merge, release, or update the dependency pin as part of validation. Report any additional real failures rather than masking them. Only a separately reviewed promotion may change the current consumer pin.

## Exact identities

| Source | Git blob | SHA-256 |
|---|---|---|
| Original SurfaceViewModel | `adee4798559b964f31fbc14feb5bcb6b09a55d51` | pinned by full Git blob |
| Repaired SurfaceViewModel | `2d5fa39f6f4abc1a878253232922ff063c242954` | `8a85402c5b2856cfc592596c8a86a975cb723850f6d1605789ef782d92f8985a` |
| Native tests (syntax only here) | `9764bbdb875aa407c011c7e2fd5b66f93b6199ee` | `f741adfd0f7cc2e8e2c59a513399c96b30fa2fb829988b128f85b37ac6bd73b0` |
| Probe Python | `4ef1eb0dea2f551e7c3b66c0e38b41a373800cb6` | `6833ea4a0ce4f2d2f1f92cb1166c04171ee33aefbe7036110f7b236da8b2e6b7` |
| Probe Swift | `5487f31125d07b1b232b1ea83934fe313e0c8ff4` | `bc37abc9f607348fee7d9c306fd453e6629a6a481f566bea78f5bcf4fc02280b` |

ComponentNode and UIState original Git blobs: `5d249f9584184dad0b1d4505c466fce47d6d64f7` and `621b4db434eedf4435977da200aad0ada8f02ccd`. Hashes identify source bytes, not signed qualification or authority.
