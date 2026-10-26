# Native streaming optimization — 2026-10-26

Tracking: https://github.com/advatar/UniversalInteractionKit/issues/134; parent UniversalInteractionKit #125. Renderer issues are disabled.

- [x] Retain exact e49880cb grouped-order baseline and CPU sample; noisy shared-host diagnostic happens to pass, so retain it and freeze counterbalanced old/new qualification before candidate timing.
- [x] Ten focused native regressions pass, including actual fast-path engagement and mixed batches: arrivals/order, batch/metadata/type replacement, data/state, root/duplicates/cycles, template/custom fallback, deletion, malformed props explicit reset and immediate node-graph release.
- [x] Implement incremental flat static leaf arrivals/updates with declared ordering and full scoped rebuild elsewhere; qualification remains pending below.
- [x] Full final renderer Debug/Release: 525 tests each (176 XCTest + 349 Swift Testing; earlier summarizer omitted 89 XCTest cases). A deliberate strong-reference mutation fails the new lifetime regression; the corrected weak index passes.
- [x] Initial source-bound consumer suites and Debug/Release timings pass; final engagement/mixed-batch regressions and truthful reporting are being verified.
- [x] Final source 5d70d02 / consumer 7d89d77: renderer 525, UniversalA2UI 142 (one opt-in skip), Interact 135 (one opt-in skip) both modes pass; dedicated benchmarks execute and pass.
- [x] Re-run final consumer suites; native 512/1024/4096 single/32 batches (3 repeats, original exponent <1.6), deterministic state and bounded admitted/refusal parity; hosted scope/callback regressions.
- [x] Claude Code source re-review finds no blocking technical defect. Final evidence audit and protected promotion are tracked in UIK #134 / PR #135.

Final raw parser/renderer qualification passes all 53 cross-run gates at 512/1024/4096; Release 4096 medians 442.46ms single and 143.63ms batched (old 73679.64/2408.06ms). Shared-host diagnostics only. This STATUS-only follow-up preserves exact tested renderer 5d70d02; UIK keeps that remote pin. Final evidence: UniversalInteractionKit/Conformance/native-streaming-20261026/.

Admission remains capped at 256. Large raw-renderer timing is not admitted-surface, frame, physical/human or clinical qualification. #64 stays deferred.
