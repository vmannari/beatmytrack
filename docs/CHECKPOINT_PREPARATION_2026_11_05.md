# Checkpoint preparation optimization — 2026-11-05

The checkpoint builder now reuses identical lane/crossing calculations and completed layouts across independently compiled, identical tracks. The canonical checkpoint algorithm, rules key, layout version, scoring, road/kerb coverage, recovery allowances and rendered art remain unchanged.

| Requirement | Implementation |
| --- | --- |
| CPP01 | Compute route normals, widths and rejoin factors once per preparation. Reuse identical lane parameters and exact serialized lane crossings. Recompute crossing results after any gate-width change. |
| CPP02 | Keep the existing per-track fast path; add bounded process-local reuse across track owners, keyed by actual geometry and versions. |
| CPP03 | Account retained layouts in the existing App/editor allowance; evict on pressure without affecting active races or joining workers. |
| CPPQ01 | Compare complete prepared layouts against the archived original; retain coverage, shortcut, notice, replay, memory and native presentation checks. |

## Implementation

`game/race/spline_gate_corridor.gd` shares the lane basis without changing ordered floating-point operations. Uniform-width lane modes reuse the same points. Crossing memoization uses exact serialized points, preserving their order and rounding; the original forward-plane tests, nearest crossing and tie order remain intact. Width changes discard the crossing memo. Non-hairpin tracks no longer rebuild an identical recovery-lane pass. Hairpin tracks reuse final edge crossings instead of calculating them again. All original lanes still participate in chain selection and notice preparation, in the original order.

`game/race/checkpoint_layout_cache.gd` stores numeric layouts, with at most four entries and a 2 MiB conservative accounting limit (serialized size × 4 plus per-entry overhead). It hashes versions, the declared content hash, complete metadata, actual grid/route/finish/bridge and kerb inputs; a stale declared hash alone cannot produce a hit. Inputs above a 16 MiB serialized-key allowance and unknown track/kerb subclasses bypass shared reuse. Deep copies isolate nested notice data. A mutex protects the bounded LRU and an eviction generation prevents a worker already preparing a layout from repopulating it after pressure.

`game/race/track_session.gd` consults this cache only after its original per-track fast path misses. `game/editor/editor_memory.gd` includes the estimate in the existing 64 MiB allowance and drops optional layouts before more expensive retained work. Active tracks keep their own installed layouts. No retention allowance increases.

The cache is process-local: restarting the app still requires preparation. Concurrent misses are not coalesced. There is no disk artifact, filesystem access, wall-clock dependency, native extension or changed competitive identity in the canonical preparation path. Avoiding a native rewrite preserves the existing arithmetic and release/export requirements while addressing measured duplicate work.

## Measurements

Pinned Windows Godot 4.7.2, frozen project, headless component comparison against the exact archived pre-task scripts. These are checkpoint-component timings, not complete race-loading or phone measurements.

| Star direction | Original build | Optimized fresh build | Identical recompiled track | Same track |
| --- | ---: | ---: | ---: | ---: |
| Forward | 4.889026 s | 3.691070 s | 17.897 ms | 14 µs |
| Reverse | 4.909554 s | 3.679957 s | 18.703 ms | 21 µs |

This sample reduces fresh Star preparation by approximately 25%, and avoids approximately 99.6% of the original work on a shared-cache hit. The forward layout remains exactly 159,200 serialized bytes and 105 gates; reverse remains 159,256 bytes and 107 gates. Independent-track hits across all nine real fixture/direction cases take 5.339–24.916 ms. The existing per-track fast path stays in the microsecond range.

Small non-spline tracks do not benefit from lane optimization; hashing/copying adds measurable miss overhead (for example Knot forward 161.316 → 191.247 ms in this sample). Shared reuse still avoids rebuilding them. Uniform and variable-width synthetic spline loops also compare exactly, including the no-hairpin branch; their runs overlap retained tests, so their timings are diagnostic only.

## Validation and evidence

The focused frozen run has **436 checks, 0 failures**, including nine complete original/candidate layout comparisons, 360 exact lane comparisons, independent-track reuse, nested-copy isolation, version/geometry fences, LRU and byte limits, actual worker/pressure ordering, App accounting and active-copy survival. The additional uniform/variable no-hairpin and input-fence suite has **35 checks, 0 failures**.

Final acceptance totals **6,039 assertions / 0 failures across 17 runs**, plus the **5,144-candidate** shortcut sweep (exit 0). The initial failed attempts below are retained separately.

| Check | Result |
| --- | ---: |
| Exact layouts/lanes, cache/worker/memory contracts | 436/0 |
| Additional uniform/variable spline loops and input fences | 35/0 |
| Physical road/kerb/finish coverage | 2787/0 |
| General checkpoint rules | 266/0 |
| Notices / notice latency / Knot notices | 537/0 + 604/0 + 252/0 |
| Bridge layers / Star consistency / forgiveness | 259/0 + 62/0 + 32/0 |
| Compact rewind | 591/0 |
| Existing retention / selected CPU worker | 12/0 + 20/0 |
| Hairpins, real drive and exact replay, Compatibility and desktop Mobile | 65/0 each |
| Settled native original/candidate views, both renderers | 8/0 each; complete pixels exact |

Both real-drive runs complete five laps in **47,712 ticks**, with zero collisions and no false checkpoint warnings, and replay the quantized recording exactly. The shortcut sweep rejects all large and beyond-recovery bypasses; the same two small reverse recovery excursions remain allowed. Numeric layouts include every prepared field, including notice dictionaries and layer data, rather than only gate counts. Final native pairs retain the 1600×1000 normal scene, materials, lighting, car and checkpoint notice: [Compatibility](evidence/checkpoint-preparation-2026-11-05/artifacts/checkpoint-preparation-settled/gl_compatibility/after-hairpin.png), [desktop Mobile](evidence/checkpoint-preparation-2026-11-05/artifacts/checkpoint-preparation-settled/mobile/after-hairpin.png).

Raw validation results are in `docs/evidence/checkpoint-preparation-2026-11-05/suite.json`, individual logs/receipts, `pixels.json` and `summary.json`. The four production sources match the frozen tested copies exactly. Two retained run receipts observe creation/correction of the unrelated new diagnostic `test_checkpoint_lane_reuse.gd` while running; their loaded tests and production sources did not change. Final focused, lane, native, selected-worker and isolated-sweep runs have no source changes.

Actual command families:

```powershell
python docs/evidence/checkpoint-preparation-2026-11-05/freeze_project.py
python docs/evidence/checkpoint-preparation-2026-11-05/prepare_probes.py
python docs/evidence/checkpoint-preparation-2026-11-05/run_check.py exact-final res://tests/test_checkpoint_preparation.gd --frozen --headless --timeout 300
python docs/evidence/checkpoint-preparation-2026-11-05/run_check.py lanes-final res://tests/test_checkpoint_lane_reuse.gd --frozen --headless --timeout 180
python docs/evidence/checkpoint-preparation-2026-11-05/run_suite.py
python docs/evidence/checkpoint-preparation-2026-11-05/run_control.py mobile
python docs/evidence/checkpoint-preparation-2026-11-05/run_control.py gl_compatibility
python docs/evidence/checkpoint-preparation-2026-11-05/run_check.py capture-settled-gl res://tests/capture_checkpoint_settled.gd --frozen --renderer gl_compatibility --verbose --timeout 240
python docs/evidence/checkpoint-preparation-2026-11-05/run_check.py capture-settled-mobile res://tests/capture_checkpoint_settled.gd --frozen --renderer mobile --timeout 240
python docs/evidence/checkpoint-preparation-2026-11-05/run_check.py selected-worker res://tests/test_race_loading_optimisation.gd --frozen --headless --timeout 180
python docs/evidence/checkpoint-preparation-2026-11-05/run_check.py shortcuts-isolated res://tests/test_star_checkpoint_shortcuts_prepared.gd --frozen --headless --timeout 180
python docs/evidence/checkpoint-preparation-2026-11-05/summarize.py
python docs/evidence/checkpoint-preparation-2026-11-05/compare_pixels.py
python docs/evidence/checkpoint-preparation-2026-11-05/checkpoint.py
```

The runner uses private workspace profiles, disabled backend configuration and dummy audio. Every run records expanded commands and before/after source hashes. Retained tests that write evidence use output-path-only copies in the task-owned frozen project. Native capture also substitutes the current task's archived original session/corridor and adds an exact pixel assertion. The first shortcut sweep retained its historical output path; the written file is byte-exact with the tracked original (SHA-256 receipt in `historical-sweep-check.json`). Its isolated repeat redirects output and passes. Frozen prepared/static asset sharing and hashes are listed in `frozen-project.json`; numeric runtime sources are checked against the final workspace by `summarize.py`.

## Findings retained and limits

The first focused test incorrectly assumed every track had spline notice-approach entries; Silmukka exposed the fixture error after both Star byte comparisons passed. It was corrected to mutate the common notice-bin field. That diagnostic hung after the script error; terminating its recorded owned process tree required escalation after sandbox access denial. No owner process was targeted. Its failed log and receipt remain. The next unfrozen run passed 431 checks but observed a concurrent unrelated Daily test edit, so final acceptance uses frozen sources.

The initial variable-width synthetic loop omitted the required widest-point bound (`piece.width`); the compiler correctly rejected it. Correcting that fixture produced 35/0 without relaxing compiler validation.

The initial Mobile capture fails its exact-pixel assertion: two car-region pixels differ by 1/255 after eight frames. Compatibility is already exact. The original-runtime controls are exact on both renderers. Allowing both stages 24 settling frames produces pixel-exact final pairs on both renderers, with the same equality assertion, full normal quality and unchanged production code. The initial Compatibility capture logs 54 ObjectDB instances/10 resources at shutdown; the original-runtime Compatibility control logs 2/1, and both final settled runs log neither. These observations are retained as timing-dependent diagnostic teardown findings, not a demonstrated production memory improvement. Windows root-certificate-store errors remain in offline logs. Initial failures are not counted as passes.

Reload/rebuild and owner acceptance remain. No device query/test, Android performance measurement, APK, owner-save modification, live/backend request, deployment or main-index write was performed. The native pixels and exact fixture layouts do not prove every possible creator document or trajectory. Graphics first-use stalls and total loading remain separate from this component optimization.

Task-only source checkpoint: `docs/evidence/checkpoint-preparation-2026-11-05/task.patch`, with forward/reverse/content receipts in `checkpoint.json`. Concurrent startup, selected-event, scenery, Garage and asset work is preserved; the patch uses the task's archived pre-edit runtime files rather than treating all existing working-tree changes as this task.

The first checkpoint content check caught a missing end-of-file newline marker in a JSON evidence diff. The patch generator now emits the standard marker and checks exact forward and reverse contents; the initial failed patch is retained separately. This affected only task-owned checkpoint scratch files, not runtime sources or the repository index.
