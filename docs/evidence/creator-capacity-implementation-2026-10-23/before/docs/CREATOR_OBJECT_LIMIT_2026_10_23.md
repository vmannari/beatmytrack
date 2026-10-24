# Creator object capacity analysis — 2026-10-23

COL-A01 traces the current limits and publication contract. COL-A02 measures desktop document, editor, tyre simulation and rendering costs. COL-A03 recommends a capacity policy. COL-A04 extends the analysis beyond the owner's initial tenfold guess. This is an analysis; the shipping 96-object limit remains unchanged.

**Revised recommendation: aim for 4,096 authored objects in the next implementation, and design toward 8,192, with separate allowances for scene complexity and actual simulated tyre stacks.** These are approximately 43 and 85 times the current count. The owner's 10× estimate was an initial guess, not a desired ceiling. The first 960-object probes are a baseline; the higher-count probes below supersede 960 as the recommendation. These are engineering targets, not a claim that arbitrary mixtures of these counts already run well on phones. The owner already reports tyre-heavy tracks working well; the measured ordinary tyre fixtures agree. Deliberately overlapping piles are kept separate from the recommendation.

Before enabling the larger allowance, address the native tyre solver's 4,096-body fallback boundary, split tyre rendering into spatial batches, reduce or budget the editor's retained copies of complex prop geometry, and make single-object updates scale with the changed object. A useful implementation should preserve the freedom to build long tyre runs instead of imposing the cost of castles or trees on every tyre. Until the solver boundary is addressed, count a tyre-stack object as one simulated body and a six-stack wall as six; remain at or below 4,096 bodies, including mixtures. This is a concrete implementation boundary, not a phone performance guarantee. A lower arbitrary blanket object cap would not solve the differences between object families.

## Higher counts without the tenfold assumption

The additional COL-A04 probe passes forty assertions and tests 2,048, 4,096, 8,192 and 16,384 entries without changing the production cap. The new headless results, log and source fingerprints are in [the higher-count report](evidence/creator-object-limit-higher-2026-10-23/report.json). It reuses the isolated component runner and original PNG bootstrap described below. Full-detail geometry stress is limited to lightweight grass patches and instanced tyres; thousands of castles or trees are not allocated.

| Authored entries | Fractional-position grass document | Integer-position flag document | Retained steps after 40 object edits |
| --- | ---: | ---: | ---: |
| 960 | 77,930 bytes | 48,296 bytes | 40 |
| 2,048 | 171,736 bytes | 102,067 bytes | 39 |
| 4,096 | 345,734 bytes | 203,282 bytes | 19 |
| 8,192 | 688,974 bytes | 405,616 bytes | 9 |
| 16,384 | 1,400,966 bytes | 810,386 bytes | 4 |

The common document ceiling is 524,288 bytes. Thus 4,096 entries leave about 174 KiB for roads, paint and other authoring data in the fractional fixture. An 8,192-entry document can fit for compact integer-position flags, but this is not a robust capacity promise for richer coordinates, longer kind names, properties or paint. 16,384 entries exceed the allowance in both examples. Raising the byte contract would need coordinated client/backend changes. Compilation is intentionally skipped for the fractional fixtures exceeding the byte limit; their geometry measurements are explicitly component-only.

| Full-detail component | Extra Godot static allocation | Build | Move one |
| --- | ---: | ---: | ---: |
| 2,048 tyre-stack objects | 1.9 MiB | 8 ms | 4.8 ms |
| 4,096 tyre-stack objects | 3.2 MiB | 12 ms | 10.1 ms |
| 8,192 tyre-stack objects | 6.3 MiB | 20 ms | 19.0 ms |
| 2,048 grass patches | 46.3 MiB | 541 ms | 133.4 ms |
| 4,096 grass patches | 91.1 MiB | 1,250 ms | 296.4 ms |
| 8,192 grass patches | 180.6 MiB | 2,727 ms | 1,082.6 ms |

The grass meshes themselves are modest: 4,096 patches contain 245,760 triangles. The expensive single-object update shows that the current retained editor path does too much work around a small edit even for simple geometry. This is an implementation issue to improve, not evidence that thousands of small props are inherently unreasonable. The 8 MiB history budget still holds, but an edit serializes the entire objects field and consequently retains fewer undo states; per-object history sharing/deltas should accompany the higher target.

The 60-step single-stack impact probe takes median 1.51 ms for 2,048 bodies and 2.97 ms for 4,096. At 4,097 bodies the existing script fallback raises the median to 19.71 ms; 8,192 takes 42.28 ms. Ordinary static-prop/hazard component scans also rise from 1.01 ms at 2,048 to 2.63 ms at 4,096 and 7.63 ms at 8,192. Filtered/spatial preparation is therefore relevant even for decorative objects that should not need hazard work. None of these timings includes a complete race, GPU execution or phone thermal behavior.

**4,096 is a useful next implementation target under the current file allowance. 8,192 is a plausible subsequent target after the specific editor, history, document-size and runtime changes above.** There is no measured justification for treating 960 as an architectural maximum, and no measured basis yet for certifying a universal 8,192- or 16,384-object phone limit. Resource budgets should determine how much of the higher count a particular mix can use.

## What the current limit counts

The limit is **96 authored object entries per document**, shared by scenery, barriers, movable props and hazards. One `tyre_stack` entry produces one simulated stack with two visible rubber tyres; a `tyre_wall` entry produces six such stacks. The present maximum is therefore anywhere from 96 to 576 authored simulated stacks when the document consists entirely of tyres. Automatically generated scenery is separate from this authored count, although adopting it into the editable document consumes an entry.

The count is repeated in `TrackDocument.validate`, the editor canvas (place/adopt/run), App (confirm run/duplicate), `RoadPieces.barrier_run`, `ObjectPopulation.MAX_OBJECTS`, the creator-v5 JSON schema and the backend native runner's shape gate. Changing just the placement message or one constant would leave import, save or publication rejecting larger tracks. The population tool also has a separate density target of 24–80 new placements, which should be considered independently.

The backend Python verifier retains a 524,288-byte document allowance and delegates document acceptance to the canonical Godot runner. The matching client/schema/canonical backend package must agree before larger tracks can publish. Existing road-section/route/helper limits of 96 are different contracts and should not be raised by a broad replacement of `96`.

## Measured ordinary tyre layouts

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. These are local Windows desktop measurements with the current native solver, not phone frame rates. Props are distributed across a 192 m square inside the editing bounds, with no intentional overlap. The impact probe starts the car moving at 12 m/s toward the first stack and runs 120 successive tyre-solver steps. It excludes the rest of the vehicle simulation and rendering. Medians below are from the retained final runs; maxima and all samples are in the JSON evidence.

| Authored objects | Simulated stacks | Tyre solver median per impact tick |
| --- | ---: | ---: |
| 96 single-stack objects | 96 | 0.270 ms |
| 960 single-stack objects | 960 | 0.788 ms |
| 96 six-stack walls | 576 | 0.463 ms |
| 480 six-stack walls | 2,880 | 1.190 ms |
| 640 six-stack walls, boundary probe | 3,840 | 1.502 ms |
| 682 six-stack walls, boundary probe | 4,092 | 1.652 ms |
| 683 six-stack walls, boundary probe | 4,098 | 21.477 ms |
| 960 six-stack walls, boundary probe | 5,760 | 33.204 ms |

The abrupt increase is explained by `native/track_geometry/tyre_contacts.hpp`: `step` returns false above 4,096 bodies. The adapter then executes the exact GDScript fallback. Live native work statistics confirm 4,092 bodies were prepared for 682 walls, while zero were prepared for 683 walls. The boundary probe has five passing assertions. No density/overlap rejection or driving change was introduced.

At 120 Hz, a full simulation tick has 8.33 ms for all work. The larger fallback measurements exceed that allowance on this desktop. They are ordinary separated-wall layouts, not deliberately coincident piles. The independent coincident-body experiment is retained in the raw results as a separate worst case; it does not justify retaining the 96-object cap for ordinary tracks.

Rewind is also proportional to simulated bodies: the packed state is 47,324 bytes for 960 single-stack objects, versus 277,724 bytes for 960 walls. The ten-second, ten-snapshot-per-second window can retain approximately 4.6 versus 26.8 MiB of those state bytes at 101 entries, before session, telemetry and container overhead. These are calculated byte estimates, not measured process-memory peaks.

## Rendering and editor memory

Tyres share geometry and are cheap to construct in the editor: 960 single-stack objects add about 0.82 MiB of Godot static allocation, with a 5.4 ms initial build and a 2.7 ms single-object update in the headless component probe. 960 walls add about 1.19 MiB, with a 10.3 ms build and a 5.4 ms update. Those figures do not include roads, ground, the complete app, GPU allocations or driver compilation.

However, the tyre mesh contains 1,200 triangles per simulated stack. The current editor and race presentation each put the tyres in one MultiMesh. In an isolated 1280×720 desktop Mobile viewport, the 40 m local camera and 240 m camera both submit every tyre triangle in one draw:

| Authored objects | Submitted tyre triangles in either view |
| --- | ---: |
| 96 single-stack objects | 115,200 |
| 960 single-stack objects | 1,152,000 |
| 96 six-stack walls | 691,200 |
| 960 six-stack walls | 6,912,000 |

This is actual renderer counter evidence on the desktop RTX 3090, not GPU execution time or Android throughput. The all-or-none visibility is also the documented [Godot MultiMesh behavior](https://github.com/godotengine/godot-docs/blob/master/tutorials/performance/using_multimesh.rst). Spatial tyre batches would let distant stacks be culled while preserving the original close-up models and physics. The twelve exact primitive-count assertions plus the unchanged shipping-cap assertion pass.

Other props have much larger active editor geometry costs:

| Full-detail editor fixture | Additional Godot static allocation | Initial build | Move one object |
| --- | ---: | ---: | ---: |
| 96 trees | 25.3 MiB | 207 ms | 7.8 ms |
| 960 trees | 247.0 MiB | 1,938 ms | 71.5 ms |
| 960 concrete barriers | 82.1 MiB | 781 ms | 62.9 ms |
| 960 mixed nature/barrier props | 146.6 MiB | 1,248 ms | 54.2 ms |
| 96 snow castles | 47.1 MiB | 1,201 ms | 15.6 ms |
| 288 snow castles | 139.2 MiB | 3,373 ms | 24.7 ms |

These are isolated full-detail editor props, not a complete road scene. The editor overview reduces draw detail but retains the underlying exact models. Existing cache-retention allowances do not cap all live prop geometry. CPU/GPU stream estimates are separately recorded and must not be confused with these measured static-allocation deltas or added to them as if they were distinct RSS allocations. 960 castles were intentionally not allocated; the 288-object measurement already demonstrates substantial cost. No result above extrapolates a measured phone limit.

A complexity allowance should use actual generated geometry/active memory and simulated stacks, with a concise actionable explanation when it binds. Exact numeric mobile memory/visible-triangle allowances still need reference-device measurement. Giving every family a nominal count of one hides the main costs. Hazard-heavy fixtures also differ: 960 oil entries take about 6.39 ms in the current prop/hazard component loop even when distant, while 960 static tree entries take about 0.59 ms. Relevant scans are candidates for filtered/spatial preparation before allowing arbitrary hazard saturation.

## Documents, history and integration

The 960-object mixed document is 73,850 bytes of compact JSON, comfortably within 512 KiB when it has no large paint payload. Forty successive object-move histories retain all forty steps and account for 3,894,304 bytes under the shared 8 MiB allowance. Validation has a median of 8.28 ms; the final full compile median is 622 ms versus 221 ms for 96 objects. Both counts expand to the same 222,768-cell grid in this fixture. The compile includes the unchanged route/raster/native preparation and is not an input-handler or frame-time measurement. Near-maximum paint can still consume the common byte allowance; raising the object count does not require raising the JSON limit.

The original baseline probe creates a validator in memory changing only the object-count comparison to 960; the higher-count extension uses 16,384 for its analysis guard. Each checks its document with that validator before compiling with an in-memory copy whose original validation gate is bypassed. Every other validation rule remains; production scripts and schema are not patched. The harnesses check that the shipping validator still rejects 97 entries. This does not demonstrate that the unmodified production editor can place/save/publish the expanded counts.

Source/contract work for an implementation includes centralizing the object allowance, replacing each placement/adoption/duplicate/run guard, deciding the population tool's density behavior, updating creator-v5 schema and native backend shape checks, and exercising save/reload/undo/practice/publication boundaries. Matching backend acceptance and target-device cold/thermal/long-session checks remain required before treating the expanded policy as supported.

## Commands and evidence

Repeat all final probes with:

```powershell
powershell -ExecutionPolicy Bypass -File docs/evidence/creator-object-limit-2026-10-23/run.ps1
```

`Headless`, `Boundary` and `Mobile` can also run separately using `-Mode`. Run the higher-count extension with `-Mode Higher`; it writes to the separate higher-count evidence directory. Each uses disposable APPDATA and `BMT_API_URL=audit-disabled`. The runner creates a component-probe project under `build/creator-object-limit`, referencing the original source and assets with directory junctions, a copied class/extension cache, and no application autoloads. The live project's configuration/imports are not edited. The direct pinned-engine fallback is used because the attempted `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_creator_object_limit.gd -CommandTimeoutSeconds 240` stopped at the sandbox's existing Windows certificate-store error. Unexpected script/runtime diagnostics remain failures.

The initial probe exposed two harness mistakes: a new dictionary key written through dot syntax became a StringName rejected by the strict authoring validator; and primitive meshes do not expose the ArrayMesh-only array-length shortcut. Explicit String keys and `surface_get_arrays` corrected the fixtures/counter collection. Initial logs remain as `initial-headless.log` and `initial-mesh-fixed.log`; their results are superseded. They were never used as passing validation evidence.

A later direct repeat encountered 1,024 compressed-image `get_pixel` errors in the unrelated Desert static luminance sampler during application autoload initialization. Its 38 assertions passed but the diagnostic gate rejected that run; `initial-compressed-texture.log` retains it. Loading the bootstrap in the full app alone did not avoid the earlier autoload. The final component project removes those autoloads and the bootstrap binds the same original Desert PNG pixels before loading NativeTrackVisual. This changes only the probe's resource loading, preserves exact Pine/Winter geometry, and does not fix or conceal the production Desert startup issue. The runner's diagnostic filter also excludes PowerShell's truncated exception-wrapper lines while retaining actual engine error lines.

The original headless component probe passes 38 assertions, the native threshold probe passes five, and the graphical Mobile tyre probe passes thirteen; the higher-count extension adds forty passing assertions. Logs, measurements, source fingerprints and the isolated task checkpoint are indexed by [report.json](evidence/creator-object-limit-2026-10-23/report.json). The follow-up ran only the new higher-count mode; the original baseline receipts remain intact. Added source is confined to the diagnostic harnesses/bootstrap and evidence runner; runtime capacity policy is unchanged. The build entry point can refresh generated build identity amid concurrent work; it is outside this analysis checkpoint. Existing unrelated workspace edits are preserved.

No phone attachment check, physical-device test, APK, live account/backend mutation or deployment was performed. GPU frame times, Android PSS, touch/thermal behavior, complete race/editor acceptance and publishing of expanded tracks remain unmeasured.
