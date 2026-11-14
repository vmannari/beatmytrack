# Car loading improvements — 13–14 November 2026

This pass implements the approved selected-car loading, prepared-loader
separation, exact mesh sharing and static Kart suit partition. Challenger
model/cache publication is excluded. Concurrent vehicle finishes, geometry,
loading code and Garage work are preserved.

## Implemented behaviour

| ID | Change | Controls |
|---|---|---|
| CLI01 | Original Kart driver/helmet resources load only when their factory is used. Prepared races load their saved assembly directly. | Full original assets remain available for full-detail construction; absent split assets fall back to the original driver. |
| CLI02 | `CarVisual` resolves optional factories through a table containing only factories requested by its fixed call sites. Vehicle factories and fitted-part revision helpers defer their optional dependencies. | The prepared source/key/structure checks and procedural fallback remain. Night optics, kit replacement, rollover extents and Volt tyre clearance use their original functions and arguments. |
| CLI03 | Offline packing shares encoded-identical immutable meshes only when every active surface finish is independently overridden. | Separate articulation nodes, current per-car materials, all attributes, indices, distance levels, metadata and bounds remain. No runtime hashing/sharing pass is added. |
| CLI04 | Completely invariant suit triangles move out of the Kart steering morph buffers. | All ten target names and every original triangle/encoded attribute remain. Mixed triangles stay animated. The static child retains live shadows. The existing anatomy finisher regenerates both split files on future driver bakes. |

The new split resources contain **583,776 B** of raw mesh streams instead of
**905,304 B**, saving **321,528 B / 35.5%**. They retain all 6,456 driver triangles;
2,761 suit triangles are static. The split adds one visible surface/draw. The
static suit deliberately receives no new distance reduction: its original
animated counterpart had no generated LODs.

The original driver, helmet and steering source are retained. Concurrent finish
work binds the same current cloth finish to both halves and is preserved.

## Stored race assets

The task-start and post-refresh inventory reads all twenty full/simple,
fixed/editable assemblies directly. Values below select simple fixed stock.
Payload counts each active mesh once, including distance/morph/shadow streams;
it excludes material/texture objects and process/driver allocation overhead.
Dependency bytes sum the stored scene and its explicitly referenced files.

| Car | Before raw streams | After | Saving | Before dependency bytes | After |
|---|---:|---:|---:|---:|---:|
| Rally | 1,023,510 | 936,762 | 86,748 | 437,314 | 413,488 |
| Kart | 1,870,564 | 1,465,672 | 404,892 | 1,216,723 | 895,928 |
| Forklift | 1,698,384 | 1,698,384 | 0 | 544,016 | 544,099 |
| Volt | 1,095,216 | 974,700 | 120,516 | 621,508 | 591,782 |
| Hover | 637,388 | 619,968 | 17,420 | 357,071 | 349,522 |

Total reduction: **629,576 raw bytes** and **381,813 dependency bytes** across
these five assemblies. The previous review's 319,580 B sharing estimate described
procedural prototypes, rather than these final prepared resources. Material and
contour changes from concurrent work also affect the inventory; the table is an
observed snapshot comparison, not attribution of every byte to this pass.

## Verification and comparison method

The dependency probe confirms loading `CarVisual` alone leaves the six tested
optional factories and both original Kart mesh resources unloaded: 8/0. The raw
driver test compares ordered encoded position, normal/tangent, UV/colour and
material-role triangle records in the neutral state and every one of ten poses:
16/0. Driver contact 27/0 and driving 72/0 also pass.

Native comparisons use the current finish in one viewport. The reference gives
each part its own mesh and restores the original unsplit driver; the candidate
uses the saved shared meshes and partitioned driver. Active materials, cameras,
poses and transforms are the same. This isolates these changes from concurrent
art edits that invalidate a simple task-start screenshot comparison.

The strict byte-identical diagnostic is retained. Compatibility Kart differences
were at most 1/255; Vulkan also showed small raster/shader differences and initial
lighting-settling controls. The final fixture waits for a stable reference and
checks the existing vehicle appearance limits unchanged: mean RGB difference
below 0.25/255, fewer than 0.5% of pixels differing by more than 8/255, and restored
reference maximum difference at most 1/255. Exactness remains separately reported;
the result is not described as universal pixel identity.

Final native comparisons pass **125/0 per renderer**, covering 30 pairs each.
Eighteen Compatibility pairs and sixteen Vulkan pairs are exact. Compatibility's
worst mean difference is 0.000067983/255, with no pixels differing by more than
8/255; Vulkan's worst mean is 0.000056140/255, with at most two such pixels.
Both reference stability and restoration controls pass. The full stock/fitted
module matrices pass **7,557/0**, and the actual five-car Garage/race integration
passes **48/0 in each renderer**. A temporary test-only audio singleton teardown
diagnostic was corrected; its first log is retained.

## Prepared refresh and concurrent work

The five-car refresh rebuilds full/simple fixed/editable bases, fitted modules,
Garage/header assemblies and five-car artwork/provenance. Two rejected refreshes
detected concurrent vehicle, shader, contour, dependency and Garage edits. Their
receipts/logs are archived in `rejected-refresh-1.zip` and
`rejected-refresh-2.zip`; no older owner sources or models were restored.

Rebuilding can reuse old distance-index buffers only when the entire encoded
master, actual engine and LOD policy match. The reuse is bounded to 32 MiB,
preserves all new source attributes, and stamps its policy. Legacy unstamped
outputs require the explicit `--reuse-validated-lods` migration flag and matching
stored LOD-source hash. Changed masters regenerate normally. This shortens the
refresh window without accepting stale geometry or weakening runtime guards.

The successful scoped source fence records 21,326 stable inputs; its strict
prepared gate passes **468 resources / 1,925 checks / 0 failures**, and the
five-photo check passes with 168 current source hashes. The image importer
verifies 260 source/import pairs, with no diagnostics or project-setting change.
Live metadata can subsequently change in concurrent producer sessions; final
handoff receipts and limits are recorded with the summary.

## Loading measurements and limits

The actual App profiler uses private offline records, ordinary five-lap practice,
the real loading cover, tick zero and the full countdown. It measures first entry,
same-track re-entry, retry, setup phases, native frame gaps and actual cache hits.
It also checks that non-Kart races do not retain the original Kart driver/helmet.
The removed eager references represented 1,057,116 B of raw unselected mesh data.

Task-start Compatibility observations were 6.579–6.843 s for first entry,
242–313 ms for re-entry, and 55–60 ms for car setup. These are fresh-process
desktop observations with existing OS/import/shader caches. Concurrent world,
contact-cache and material changes prevent assigning an overall timing delta
solely to this pass.

| Current actual App case | App ready | First race | Re-entry |
|---|---:|---:|---:|
| Rally, Compatibility | 1.928 s | 6.094 s | 297 ms |
| Kart, Compatibility | 2.204 s | 5.320 s | 334 ms |
| Forklift, Compatibility | 2.188 s | 5.161 s | 278 ms |
| Volt, Compatibility | 1.904 s | 4.904 s | 278 ms |
| Hover, Compatibility | 2.010 s | 4.915 s | 233 ms |
| Rally, four fitted categories, Compatibility | 2.409 s | 5.312 s | 311 ms |
| Kart, desktop Vulkan Mobile | 1.947 s | 6.948 s | 591 ms |

All fourteen entries hit a prepared base. Non-Kart cases retain neither original
nor partitioned Kart assets; Kart loads the partitioned driver and retains
neither original driver nor full helmet in these observations. The actual setup
phase is approximately 52–65 ms for the five first Compatibility stock entries,
and approximately 5–8 ms on re-entry. Remaining first-entry time also includes
world/feature/native preparation. No Android performance, FPS or thermal claim
is made.

## Reproduction

```powershell
python scripts/run_car_loading_improvements.py driver-current --script=res://tests/test_car_loading_driver_split.gd --headless
python scripts/refresh_car_loading_improvements.py
python scripts/run_car_loading_improvements.py native-final-gl_compatibility --script=res://tests/test_car_loading_native_pairs.gd --rendering-method gl_compatibility
python scripts/run_car_loading_improvements.py load-compact --script=res://tests/profile_car_loading_improvements.gd --rendering-method gl_compatibility -- --car=compact --phase=after
```

Evidence is under `docs/evidence/car-loading-improvements-2026-11-13/`.
Generated native files and photographs are separate from the source checkpoint.
No device query, APK/export, deployment, backend request, owner save/process
change or main-index staging is performed by this pass. Owner appearance and
physical-device loading acceptance remain separate from desktop qualification.

## Final handoff

[Summary and command receipts](evidence/car-loading-improvements-2026-11-13/summary.json),
[source checkpoint](evidence/car-loading-improvements-2026-11-13/source-checkpoint.json).

The final five-car prepared audit repeats 468-resource / 1,925/0, production
parsing passes 562/0, and the scoped wash suite passes 1,383/0. Final integration,
appearance, module and timing commands retain their individual source fences;
earlier concurrent generated-scene, identity/project and index changes are
recorded without overwriting their owners' work. The source-only checkpoint
contains eleven modified files and thirty-two new source/UID files, applies and
reverses byte-exactly, and leaves the index unchanged during its own verification.
Its Kart baseline retains the concurrent finish functions and composes their
static-child finish call with this pass's partition.

Automatic approval review blocked recursive removal of the verified task output,
reporting only "blocked by policy". The active `.keep` marker was removed and the
prescribed retention cleanup succeeded. Approximately 137 MB of temporary
profiles/output remain under `build/car-loading-improvements-2026-11-13`, subject
to ordinary retention. They were not moved into permanent evidence. The cleanup
reports 24.14 GiB of build output, with recent/protected entries above the 20 GiB
target. Relevant native comparisons, concise receipts and source data are retained.
