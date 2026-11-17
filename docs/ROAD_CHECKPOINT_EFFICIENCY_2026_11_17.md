# Road and checkpoint preparation efficiency — 17 November 2026

Applied equivalent CPU preparation algorithms. Star's complete checkpoint preparation fell from **2.769 s to 1.080 s (61.0%)** in the final paired comparison. Complete asphalt road generation improved by **8.7–10.8%** in the three asphalt themes tested. These changes preserve the existing road mesh streams and complete checkpoint layouts. They do **not** establish a 50% improvement in whole-game startup or total race entry.

## Requirements and implementation

| ID | Requirement | Applied change |
| --- | --- | --- |
| RCE01 | Generate roads more efficiently while preserving their appearance | Compute each polygon's ordered winding sum once and reuse its corner miters. Batch the existing rounded asphalt lip/side emission through the existing native extension and typed engine bindings. Retain original contour probes, subdivision, triangle winding, normals, colour, UVs and materials. |
| RCE02 | Prepare checkpoints faster without changing race acceptance | Optional native ports of recovery-lane generation/loop removal, finite lane/gate intersections and route projection. Preserve float-vector/double-scalar rounding, sorted segment order and nearest ties. Retain the existing selection, warning and runtime race algorithms. |
| RCE03 | Integrate safely with actual race entry and current caches | Preparation-owned route index, no new persistent cache, original script fallback, unchanged prepared-data contracts and retained-memory limits. Custom track scripts retain their projection override. Build Windows x86-64 and Android ARM64/x86-64 libraries with the installed pinned toolchain. |
| RCE04 | Make the result independently reviewable | Frozen task-start source oracles; complete byte comparisons, retained rejected experiments, source fences, native fingerprints and reversible private Git checkpoint. Preserve the shared index and concurrent work. |

Runtime source scope: `game/race/spline_gate_corridor.gd`, `game/track/geometry_acceleration.gd`, `game/track/road_edges.gd`, `game/track/native_track_visual.gd`, `native/track_geometry/track_geometry.cpp`, new `checkpoint_geometry.hpp` and `asphalt_sides.hpp`, the extension descriptor and its three native libraries. Native provenance, three diagnostic/regression scripts, task runners, this report and marked project-status entries accompany the change. `track_session.gd`, `road_gate_coverage.gd`, compiler data, rules keys, vehicle models and shaders are unchanged by this task.

## Measured effects and limits

Cache-disabled paired checkpoint preparations, in one pinned-engine process against the independently retained original:

| Track | Original | Applied | Reduction |
| --- | ---: | ---: | ---: |
| Star | 2.769 s | 1.080 s | 61.0% |
| Star, reversed | 2.801 s | 1.092 s | 61.0% |
| Uniform-width closed spline | 406 ms | 156 ms | 61.6% |
| Variable-width closed spline | 390 ms | 152 ms | 61.1% |

The same complete layouts remain exact for Silmukka, Dust cloud, Over and under and Knot, including supported reversed starts. Their small preparations are roughly 91–197 ms with the change; the individual paired samples include both improvements and small regressions. This is not a claim that every track is 61% faster.

Full road-array construction, with both retained and disk caches cleared:

| Track/theme | Original | Applied | Reduction |
| --- | ---: | ---: | ---: |
| Star / Pine | 3.099 s | 2.829 s | 8.7% |
| Star / Storm | 3.225 s | 2.925 s | 9.3% |
| Star / Night city | 3.106 s | 2.771 s | 10.8% |
| Star / Desert | 3.642 s | 3.472 s | 4.7% |
| Star / Winter | 1.891 s | 2.087 s | −10.3% |
| Overlapping bridges / Desert | 1.472 s | 1.366 s | 7.2% |

The asphalt port does not run in Desert or Winter. Those differences demonstrate the variability of the single-pair measurements; no speed benefit is attributed to the unchanged loose-surface path. These are local desktop preparation measurements, not Android frame-rate results. Complete packets for the pairs coexist during comparison, and diagnostic timing has overhead.

The detailed Star profile shows why checkpoint preparation improved: crossings 1,095.5→67.8 ms, route projections 690.8→39.5 ms and lane preparation 439.4→63.6 ms. Rounded asphalt side preparation improves 651.8→504.5 ms. The separate instrumented road-plus-checkpoint total is 7.533→5.019 s, about 33%; nested stage timings must not be added again. Raw values are in `kernels-road-detail-metrics.json` and `kernels-final-metrics.json` under the evidence folder.

The final profile's remaining costs include road generation 3.747 s, checkpoint preparation 1.272 s, road-piece preparation 1.022 s, shoulder emission 763 ms, road cross-section coverage 582 ms and asphalt side construction 505 ms. Asset/script loading and first rendering also remain. The earlier [50% loading plan](LOADING_50_PERCENT_PLAN_2026_11_17.md) demonstrated a separate prepared-world package prototype; that prototype is not shipped by this change. Whole-game startup and a 50% total race-entry reduction remain outstanding.

## Validation and reproduction

All runs use `godot-version.txt`: `4.7.2.stable.official.ed1daf0bf`. Private profiles disable network configuration and use Dummy audio. Every runner receipt records command, profile, exit status, diagnostics and changed-source fence. Sources for the algorithm oracles are retained in `docs/evidence/road-checkpoint-efficiency-2026-11-17/before/`; no disposable build copy is required to understand those originals.

Representative commands from the repository root:

```powershell
python scripts/road_checkpoint_efficiency_2026_11_17.py prepare
python scripts/road_checkpoint_candidate_2026_11_17.py native
python scripts/road_checkpoint_candidate_2026_11_17.py miters
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BuildTrackGeometry -NativePlatform all
python scripts/road_checkpoint_efficiency_2026_11_17.py checkpoints-final res://tests/test_road_checkpoint_efficiency_2026_11_17.gd --headless --profile kernel-efficiency-2026-11-17-checkpoints-final -- --fixtures=star_spline_lap,silmukka,dust_cloud,over_and_under,knot --reversed
python scripts/road_checkpoint_efficiency_2026_11_17.py road-native-final res://tests/test_road_geometry_efficiency_2026_11_17.gd --headless --profile kernel-efficiency-2026-11-17-roads-native-final
python scripts/road_checkpoint_efficiency_2026_11_17.py kernels-final res://tests/profile_road_checkpoint_kernels_2026_11_17.gd --headless --profile kernel-efficiency-2026-11-17-kernels-final
python scripts/road_checkpoint_efficiency_2026_11_17.py app-compatibility res://tests/profile_loading_fixes.gd --live --profile road-efficiency-app-gl -- --star --disable-world-cache --car=compact --theme=pine
```

The historical experiment commands above describe the actual runs; `prepare` deliberately refuses to overwrite an existing private experiment. For an existing live implementation, `--live` runs the selected script directly against `game/` with the same private profile and source fence. The new comparison scripts default to the retained source-oracle paths; the original experiment supplied their absolute paths with `BMT_ALGORITHM_REFERENCE` and `BMT_ROAD_REFERENCE`.

Completed checks:

- Checkpoint oracle: **710/0**, full encoded layouts including notice cells/reach, gate order, road/recovery widths, bridge layers and optional script fallback; includes direct projection/crossing/lane cases and invalid-input fallback sentinels.
- Road oracle: **25,973/0**, all five themes and overlapping bridges. Exact pre-packing mesh streams and independent original corner miters in both winding directions. The retained builder is a typed subclass overriding only the changed method; an execution marker verifies that original method actually runs. Native batch validation proves rejection leaves no partial geometry.
- Detailed final profile: **23/0**, real cache-free road and checkpoint preparation.
- Existing spatial-index oracle **40/0**, checkpoint rules **266/0**, hairpin shortcuts/recovery **65/0**, bridge-layer races **259/0**, Knot warning coverage **252/0**, forgiveness **32/0**, road cache **90/0**, driving **72/0**.
- Private shipping parser **581/0**; live parser **583/0** (see the source-fence qualification below). Actual App **16/0 per desktop renderer**. Storm road views **3/0 per renderer**, including exact complete scene/material signatures and exact native pixels. Results are recorded in `validation.json` and the corresponding receipts.

Actual App tests preserve the selected prepared car, five laps, tick zero, complete countdown, re-entry and retry. The Compatibility run passes **16/0**, with fresh entry 11.616 s, repeat 290 ms, retry 11–13 ms and checkpoint worker 1.175 s. These are integration observations, not a paired total-loading reduction claim.

Desktop Mobile also passes **16/0**, with fresh entry 13.495 s, repeat 576 ms, retry 12 ms and checkpoint worker 1.238 s. Both App runs have zero changed-source inputs and no diagnostics. Render comparisons retain [Compatibility original](evidence/road-checkpoint-efficiency-2026-11-17/views/gl_compatibility/storm-star-original.png) / [native](evidence/road-checkpoint-efficiency-2026-11-17/views/gl_compatibility/storm-star-device.png) and [desktop Mobile original](evidence/road-checkpoint-efficiency-2026-11-17/views/mobile/storm-star-original.png) / [native](evidence/road-checkpoint-efficiency-2026-11-17/views/mobile/storm-star-device.png). PNG files as well as decoded pixels are exact within each renderer. These existing renderer controls compare the complete scalar and native road paths; their timings are not incremental before/after measurements for this task.

Windows and both Android native builds pass. `native-build.json` records exact source/library hashes and sizes. `llvm-readelf -lW` verifies every Android load segment uses `0x4000` alignment. These builds use the existing pinned godot-cpp checkout, MinGW and NDK r28b, API 24 and `-ffp-contract=off`; no new SDK or dependency is introduced.

## Retained rejections and qualification boundaries

- Reversing the gate/segment spatial index was byte-exact but slower: Star 3.494→4.292 s. Rejected.
- Skipping repeated coverage-grid centre keys added bookkeeping overhead on small tracks. Rejected; `road_gate_coverage.gd` remains original.
- Initial generic native `Object.call` loops were slower than intended. Final kernels use the project's existing typed engine bindings, including the pinned `Geometry2D.segment_intersects_segment` hash 2058025344. The slower measurements remain retained.
- Initial native compilation referenced an unavailable generated Geometry2D wrapper; corrected by using the existing public engine-binding pattern. Initial test adapters also exposed a packed-array conversion error and type-inference/self-type constraints. Corrections preserve the independent original calculations and exact assertions.
- Legacy checkpoint tests initially could not write their hardcoded evidence paths in the isolated project. Required private output directories were created; unchanged tests then passed. Original failed logs remain.
- The broader road-piece-materials UI test stops because `app.canvas` is null after its old editor-entry fixture. The same failure reproduces after restoring all four task-start runtime sources in a separate private control. Its geometry assertions are not weakened; this legacy UI test remains unqualified.
- The first live parser reaches **583/0** but its source fence rejects 83 concurrent vehicle scene changes. The repeat also parses **583/0** but rejects two further concurrent inputs. Those changes are preserved. The final task-only fence verifies all four applied runtime files and native build inputs/libraries against the qualified bytes; whole-tree prepared vehicle/cache readiness is not claimed by this road/checkpoint task.

The native ports prepare the same geometry and layouts; they do not reduce render detail, change draw counts, introduce simplified checkpoints or change competitive identities. Existing cache contents remain valid because their values are equivalent. The native feature is optional, including when an already running editor still has its previous DLL loaded.

Physical-device testing was not performed. Android execution, phone loading/memory/frame behaviour and owner appearance acceptance remain. A new Godot process is needed to use the rebuilt native library. No owner saves/processes, live services, export, deployment or main Git index operation is part of this task.

## Preservation and checkpoint

`publication.json` fences the four runtime writes against their exact task-start bytes. `native-build.json`, all raw logs, metrics, source fences and control receipts remain in the evidence folder. `source-checkpoint.json`, `source.patch` and `build/road-checkpoint-efficiency-2026-11-17/source-checkpoint.bundle` provide an exact forward/reverse-checked private checkpoint, including native rollback bytes. The previous referenced Windows DLL remains recoverable from the native archive. Generated build identity updates from the development wrapper and unrelated/concurrent work are excluded from the task patch.

Standard retention is applied with `scripts/clean_build.ps1 -Apply`; its receipt is retained with the evidence. No permanent task-retention pin is added.
