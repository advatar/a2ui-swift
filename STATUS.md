# Native streaming optimization — 2026-10-26

Tracking: https://github.com/advatar/UniversalInteractionKit/issues/134; parent UniversalInteractionKit #125. Renderer issues are disabled.

- [x] Retain exact e49880cb grouped-order baseline and CPU sample; noisy shared-host diagnostic happens to pass, so retain it and freeze counterbalanced old/new qualification before candidate timing.
- [x] Nine focused native regressions pass: arrivals/order, batch/metadata/type replacement, data/state, root/duplicates/cycles, template/custom fallback, deletion, malformed props explicit reset and immediate node-graph release.
- [x] Implement incremental flat static leaf arrivals/updates with declared ordering and full scoped rebuild elsewhere; qualification remains pending below.
- [x] Full renderer Debug/Release: 435 tests each. A deliberate strong-reference mutation fails the new lifetime regression; the corrected weak index passes.
- [ ] Run consumer suites; native 512/1024/4096 single/32 batches (3 repeats, original exponent <1.6), deterministic state and bounded admitted/refusal parity; hosted scope/callback regressions.
- [ ] Recorded Claude Code review, exact-pin promotion and required CI.

Admission remains capped at 256. Large raw-renderer timing is not admitted-surface, frame, physical/human or clinical qualification. #64 stays deferred.
