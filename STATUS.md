# Native streaming optimization — 2026-10-26

Tracking: https://github.com/advatar/UniversalInteractionKit/issues/134; parent UniversalInteractionKit #125. Renderer issues are disabled.

- [ ] Retain exact e49880cb streaming baseline and host/source identities.
- [ ] Cover ordered/out-of-order/late leaves, replacement, data bindings, root changes and nested/template/custom fallback.
- [ ] Optimize flat static Column/Row/List leaf updates without changing per-message tree state or scoped state migration; preserve full rebuild elsewhere.
- [ ] Run Debug/Release renderer and consumer suites; native 512/1024/4096 single/32 batches (3 repeats, original exponent <1.6), deterministic state and bounded admitted/refusal parity; hosted scope/callback regressions.
- [ ] Recorded Claude Code review, exact-pin promotion and required CI.

Admission remains capped at 256. Large raw-renderer timing is not admitted-surface, frame, physical/human or clinical qualification. #64 stays deferred.
