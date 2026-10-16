# Template-scope rebinding status — 2026-10-16

Tracking: https://github.com/advatar/UniversalInteractionKit/issues/100
Base: `57d42442df7d1c786a54357fd1cbe8c8371f4b54` (UniversalA2UI's current pin).
Branch: `fix/template-scope-rebinding-100`.
Upstream inspiration: a2ui-project/a2ui `7c61659591791b17f6698a9c6a2ea1e986a0b4df`; that newer architecture differs from this fork.

## Plan recorded before implementation

- [x] Verify the consumer pin, source mechanisms, upstream change and branch base.
- [ ] Reproduce scope retention using exact source-extracted reconciliation/migration methods in a bounded Swift probe.
- [ ] Add real SurfaceViewModel/message/action-helper native regression tests for equal-length template scope changes, current payload/label identity and same-scope preservation.
- [ ] If demonstrated, restrict node reuse and UI-state migration by the resolved data-context path without changing wire IDs.
- [ ] Run available before/after probes and targeted mutation controls; record exact source identities and limits.
- [ ] Run the full renderer tests and hosted native button activation on an approved Mac before consumer promotion.
- [ ] Run shared UniversalA2UI consumer gates on that exact repaired revision before changing any pin.

## Scope and evidence discipline

The currently available executor is Swift 6.2.1 on Linux. A source-extracted probe is not an Apple renderer build or native action test. Apple-only tests remain NOT_RUN until genuinely run. No no-op SwiftUI stub is to be counted as renderer qualification.

No production pin, existing branch, wire ID, public authority API, CI, signing, global setting, consumer application or real data is changed. This focused dependency repair requires review and Apple validation; it is not to be merged/deployed on source-only evidence. Preserve all unrelated work and original source/fixture evidence.
