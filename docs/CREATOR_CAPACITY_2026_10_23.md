# Creator capacity implementation — 2026-10-23

The owner approved the capacity package following the [capacity analysis](CREATOR_OBJECT_LIMIT_2026_10_23.md). The implementation replaces the 96-object allowance with **4,096 authored objects**, subject to independent tyre and prop-memory admission. Tenfold was the initial estimate, not a ceiling; this increases the count about 43 times. No deployment is included.

| Requirement | Implemented behavior |
| --- | --- |
| CAP01 | One shared 4,096-object policy covers placement, adoption, duplication, free/roadside runs, population, document validation and canonical verification. Route/helper and road-piece limits retain their own meanings. |
| CAP02 | At most 4,096 simulated tyre stacks: a wall consumes six, a stack one. The editor checks before committing; imported and published documents obey the same domain rule. This stays within the existing native solver's supported boundary. |
| CAP03 | More than 96 tyre stacks render through 32 m spatial batches sharing the original mesh/material. Membership follows moving tyres. The original indexed transform buffer remains available; exact transforms, physics and scene reuse are retained. |
| CAP04 | History shares immutable per-object binary chunks and unchanged 64-object accounting blocks. Undo/redo retain their shared 8 MiB weighted allowance and 40-state maximum. Editor grouping reuses unchanged clipped components and mesh uploads. |
| CAP05 | Ordered derived hazard groups and spatial queries remove unrelated scenery from fluid/ramp/bump work. Soft props retain full simulation. Distant speed bumps still advance the spring. Value checks detect public source edits; concurrent scoped query integration checks once per simulation/presentation scope. |
| CAP06 | Creator documents allow 1,048,576 UTF-8 bytes in client storage, runner, backend validation, lightweight publication admission, schema and offline-sync tooling. The sync script was edited but was not run. |
| CAP07 | A shared 128 MiB conservative estimate rejects excessive authored prop geometry before generating meshes. A generated table covers 58 kinds in five biomes, including maximum continuous spans. Tyres share their mesh cost and consume 192 estimated bytes per expanded stack. All current scenes use the same rule; there is no small-scene exemption. |

The memory estimate counts conservative geometry streams and retained data, not total application memory, Android PSS, texture residency, GPU driver allocations or transition peaks. It is a provisional engineering guard, not a phone-calibrated memory guarantee. For example, 4,096 light grass props estimate 131,006,464 bytes, while 4,096 Winter castles are rejected. A 4,096-object allowance does not promise 4,096 arbitrary complex props.

## Actual validation

Pinned Godot: `4.7.2.stable.official.ed1daf0bf`. Raw logs, native images, corrections, commands and hashes are in [the evidence report](evidence/creator-capacity-implementation-2026-10-23/report.json).

| Check | Actual result |
| --- | --- |
| Focused capacity | 2,490 headless / 2,491 Compatibility / 2,491 desktop Mobile checks, zero failures |
| Boundary/storage | 4,096 props accepted; 4,097 rejected. Exactly 682 walls + four stacks accepted; another stack rejected. A 571,518-byte document with 4,096 props and 16,384 paint points saves and reloads exactly. |
| Canonical backend | Both focused pytest tests pass against an actual staged Godot subprocess, including a document above the old 512 KiB limit. Direct canonical boundary matrix accepts/rejects all four expected cases without engine diagnostics. |
| Backend regression | 57 passed, two skipped, 15 deselected in selected verifier/publication SQLite tests; Ruff passes all four changed backend modules/tests. |
| Exact driving | Five cars × 240 ticks in a 4,096-object mixed scene match the original full-scan implementation byte for byte; ramp queries and in-place source invalidation also pass. Existing tyre equivalence 13,200 and dynamic-prop 16,924 checks pass. |
| Editor | T05–T11 321 checks in headless and both desktop renderers; workflow 254, preparation 269, incremental objects 51 and remaining issues 120 pass. |
| Integration | Creator 113, hazards 212, speed bumps 9,046, App 141 and compact rewind 591 pass. |
| Full parser | Final 1,011 project scripts, zero failures. |

In the 1,024-stack, 960×540 local-camera fixture, both desktop renderers produce **byte-identical before/after images**. Submitted tyre primitives fall from 1,228,800 to 132,000. This measures frustum submission in that camera, not phone frame rate or a general ninefold speedup.

Forty 4,096-object history revisions retain all 40 states at a weighted 2,491,468 bytes; the earlier whole-field implementation retained 19 in the comparable analysis fixture. Capturing and trimming all 40 takes about 485–531 ms across the final desktop runs. A one-object grass edit retains 1,343 of 1,344 mesh uploads. Paired editor update times are 313.117→198.824 ms headless, 359.975→141.021 ms Compatibility and 343.943→157.925 ms desktop Mobile. These updates still scan and plan the full object list and are not constant time. Cold graphical builds in this fixture still take seconds.

## Corrections and limits retained in evidence

- Initial primitive mesh cost baking incorrectly used ArrayMesh-only APIs; the final path retains fast ArrayMesh counts and reads primitive arrays only when needed.
- Canonical staging needed the new data-only dependencies and an adjacent concurrent attempt-evidence dependency. The road subset helper now accepts RefCounted without importing presentation types, with an explicitly typed empty triangle array. The first untyped assignment produced runtime errors despite completed assertions; the final T05–T11 runs are clean apart from the documented startup certificate diagnostic.
- Hazards/speed-bump fixtures now await actual App/editor preparation. Their assertions remain intact. The maximum-paint regression explicitly compares against the former 512 KiB boundary; the new tests exercise the expanded boundary separately.
- A first full-app tyre test completed all comparisons then crashed at teardown. Its isolated final run exits zero. The separate historical `test_rewind` fixture imports retired native-v1 tracks, fails under the current import policy and was interrupted after its script error; no old-format conversion or assertion relaxation was added. The current compact rewind suite passes.
- Windows sandbox startup can log a certificate-store error. Native test receipts retain it and exclude only that exact environmental diagnostic. Production backend verification still rejects every engine error. A disposable staged verifier uses the existing certifi roots as a test-only project override; the final real backend subprocess tests and direct matrix have no engine errors. No machine trust settings or production filters changed.
- Full parser attempts encountered concurrently unfinished gameplay fixtures (resume-credit path, road-preparation helper and Variant inference in an original-control fixture). The final 1,011-script parser run passes after those concurrent fixtures were completed; the failed control receipt remains in `initial-parser-concurrent-control.log`.

Current creator-track-v5/canonical formats and driving versions are retained. The concurrent current-format-only import policy, editor ownership/worker changes, race loading, audio, menu and backend work are preserved. Matching client/API/worker canonical sources must ship together before online publication accepts the expanded documents.

Remaining acceptance: reference-phone sustained driving, cold/thermal/memory behavior, long editing sessions, touch and owner appearance acceptance, and calibration of the provisional prop estimate. No phone attachment check or device test, APK, live backend/account mutation, social send or deployment was performed.
