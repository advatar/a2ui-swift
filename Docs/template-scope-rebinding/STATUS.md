# Template-scope rebinding status — 2026-10-16

Tracking: https://github.com/advatar/UniversalInteractionKit/issues/100
Base: `57d42442df7d1c786a54357fd1cbe8c8371f4b54` (UniversalA2UI's pin when inspected).
Branch: `fix/template-scope-rebinding-100`.
Upstream inspiration: a2ui-project/a2ui `7c61659591791b17f6698a9c6a2ea1e986a0b4df`; that newer architecture differs from this fork.

## Plan and execution

- [x] Verify the consumer pin, source mechanisms, upstream change and branch base.
- [x] Record the plan before code in `6e895e3`.
- [x] Execute exact source-extracted methods with real core node/state definitions; original wrong-scope and state-migration regressions reproduced in both optimization modes.
- [x] Add eight native SurfaceViewModel/message/action-helper tests before the repair, commit `a79e6c1`. Native execution NOT_RUN; syntax parsed only.
- [x] Repair one production file in `fa3fb4e`: require equal dataContextPath for reuse and state migration; template/wire IDs unchanged.
- [x] Repaired probe 9/9 at -Onone and -O; two logic mutations caught at -Onone; source-pin negative control refuses before compile.
- [x] Preserve raw probe results and exact source identities in VERIFICATION.md.
- [ ] Actual Apple renderer/core test run, including baseline failure and repaired pass, on an approved isolated Mac checkout.
- [ ] Hosted native button activation and actual shared-consumer regression gates on the exact candidate revision.
- [ ] Independent review and separately authorized dependency promotion. No pin changed here.

## Boundaries

The available executor is Swift 6.2.1 on Linux. The initial dynamic Observation link failed; the installed static runtime ran the real node/state definitions and extracted methods without altering production source. This is a bounded tree/state probe, not a full Apple renderer build, wire parser, data resolver or button dispatch test. No source-only result counts as Apple qualification.

No existing fork branch, wire ID, public authority API, consumer manifest, CI, signing, global setting, product application or real data was changed. Keep the repair reviewable and unmerged until the native/consumer gates are demonstrated. Preserve all unrelated work and original evidence.
