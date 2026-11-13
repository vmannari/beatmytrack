# Shared graphics preparation — 2026-11-04

Implemented the requested controlled prototype across race scenery, live/preloaded Garage, custom headers and thumbnail captures. Compatible completed draws now contribute to one bounded process-local registry. Race and Garage staging use adaptive batches instead of always scheduling one material program per interval. The production rendering, geometry, cameras, picture sizes, antialiasing, reflections and final settle sequences remain in place.

This reduces redundant **warm preparation intervals**. It does not establish a reduction in the earlier Pine 24.1-second first-use world-rendering measurement, startup time, phone loading time or worst-case driver compilation stall. Compatibility still draws the actual programs; no precompilation switch replaces that work. See the [Godot pipeline compilation documentation](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html).

## Implementation and validity

**GPC01 — one conservative registry.** `game/rendering/graphics_preparation.gd` stores at most 512 string receipts and bounded context descriptions. It retains no scene, mesh, material, texture or GPU handle. Native property *names* are cached; current values are reread. ShaderMaterial keys inspect shader identity/source rather than asking for the dynamic uniform property list, which can itself trigger lazy shader creation. Resume, memory warning and tree exit invalidate the registry; an epoch rejects obsolete work completing after invalidation.

Receipts distinguish renderer, viewport pipeline settings including AA, environment/sky features, camera projection/layers, lighting, geometry format, material modes/flags/texture presence, custom shader source, overlays, next passes and relevant mesh features. Changing a source after a yield prevents publication. Lighting includes complete layer membership of visible-source geometry: a mesh visible on layer 1 that also occupies layer 4 can receive a layer-4 light. Temporary Garage warm-light clones on unrelated layer 8 do not falsely change the real view's light layout.

Directional contexts can reuse program preparation across different owners when those features match. A spot/omni context additionally requires the same mesh instance, pose, bounds, camera pose/projection extent and complete light influence settings. Forced culling margins can change local-light selection, so staging does **not** publish spatial receipts. Normal completed full-view captures publish those instead. Contexts containing ReflectionProbe, LightmapGI or VoxelGI fail closed for sharing. Skinned/blend-shape meshes and particle emitters do not gain generic reusable receipts; existing dedicated particle preparation remains responsible for real emissions.

**GPC02 — bounded adaptive native staging.** `world_render_preparation.gd` is shared by Game and the preloaded Garage. The opening Garage keeps its existing proxy target and uses the same feature keys and batching policy. Both start with **one program**, permit up to **four** after two successful draws taking at most 50 ms each, and return to one after a slow/failed draw or context change. Each program submits at most eight representative objects. The duration includes cooperative frame yields; this is a scheduling heuristic, not a GPU-time guarantee. Slow native compilation remains unbounded by this threshold. Original visibility, culling margins, retries, floor/car/room priority and navigation cancellation are preserved.

**GPC03 — real views contribute without extra captures.** Header, thumbnail and live/preloaded Garage take a weak source snapshot before their existing full settle/capture sequence and publish only unchanged, camera-visible eligible sources afterward. Header retains five draws. Garage retains four final full main/reflection settles. Thumbnail retains its 2048×512/4×AA main view and 768×192/2×AA shared-world planar reflection. No extra 3D world or cloned car was introduced. Opening-Garage proxy submissions certify only that local preparation pass; they cannot certify another view's pipeline.

**GPC04 — ownership and appearance.** In-flight sources are weak references. Owner release restores held geometry/margins and disposes proxy copies. A bounded process cache is not a new retained-scene pool. Production header/thumbnail metadata calls do not alter image pixels or capture counts. The renderer, authored appearance gates and all final reflections remain intact.

## Controlled performance observations

Godot 4.7.2, desktop NVIDIA RTX 3090, Compatibility. Each pair replays the archived task-start queue and new queue on the **same already-built native scene**, with settled GPU programs, and compares the final image byte for byte. These are individual preparation-stage observations, not aggregate startup/entry improvements or cold-driver benchmarks.

| Same-owner replay | Before draws | Shared draws | Before stage | Shared stage | Final pixels |
| --- | ---: | ---: | ---: | ---: | --- |
| Pine | 34 | 10 | 275.155 ms | 77.357 ms | Exact |
| Winter | 35 | 10 | 279.630 ms | 84.422 ms | Exact |
| Full live Garage, both reflections | 43 | 12 | 348.743 ms | 105.240 ms | Exact |

Pine/Winter receipts are `same-owner-race-final.json`; Garage is `final-garage.json`. Reduced scheduled draws are directly observed. The timings are warm samples; no statistical or cold improvement is inferred. The final cold Garage scheduling fixture still records a **3697.945 ms** maximum draw and 39 warm calls. Earlier wider initial batching recorded 6035 ms in that fixture. These unmatched observations motivated the conservative adaptive start; they do not prove a maximum-frame improvement.

Cross-owner reuse, AA/light/source isolation, exact local-light restrictions and completed-capture publication are exercised separately by the native shared component fixture. The real header/thumbnail integration checks verify their contributions. Different render contexts intentionally miss rather than reuse questionable work; the cache does not assert all four view types can share every program.

## Native verification and receipts

All commands use `docs/evidence/graphics-preparation-2026-11-04/run_check.py`, which pins the engine, records the exact command/process/source hashes, uses a private APPDATA under `build/graphics-preparation-20261104`, disables the backend URL and selects Dummy audio. `run_final_checks.py` runs the final Compatibility matrix serially. Its individual receipt/log/JSON files are authoritative; `summary.json` includes **all attempts**, including failures and earlier source revisions.

Selected final checks:

| Fixture / receipt label | Scope | Assertions |
| --- | --- | ---: |
| `final-components-compat`, `final-components-mobile` | Native shared keys, real draws, cross-owner reuse, mutation, AA/light/epoch isolation, bounded registry, cancellation and exact pixels | 168/0 each |
| `final-buckets` | Retained original single-program retry/order contract, headless | 41/0 |
| `final-editor` | Retained editor graphics preparation | 91/0 |
| `final-warm` | Retained permission/input/scheduling/adoption gates | 16/0 |
| `same-owner-race-final` | Real App Pine/Winter before/shared on same Game, full root pixels, canonical tick 0 | 20/0 |
| `final-garage` | Full native Garage before/shared on same owner, both reflections and exact pixels | 11/0 |
| `final-header` | Five custom headers, native pixels around receipt publication and existing appearance gate | 26/0 |
| `final-thumbnails` | Five full custom pictures, actual planar reflection, dimensions/AA, exact publication pixels, resource release | 18/0 |
| `final-entry` | Actual App Garage entry, three sizes, hidden/input/resource/owner fences | 61/0 |
| `final-compat-laps` | Full retained first-emission/first-lap/loading interruption integration | 123/0 |
| `final-mobile` | Full retained integration on desktop Mobile | 133/0 |
| `world-lifecycle-verbose`, `world-lifecycle-control` | Navigation, car/selection/scope changes and teardown after first native stage; new versus archived world queue | 10/0 each |
| `before-desert-mobile` | Archived world queue, first Desert lap and emission | 13/0 |

The Mobile integration completes five biome opening laps with zero contacts. First-emission draw pipeline deltas are zero. Desert creates one later draw pipeline; the archived queue reproduces the same one, so this is not claimed solved. The integration wrapper only disables unrelated optional Garage preloading between rapid race entries; all retained race/emission/cancellation assertions remain. It changes no production preloading policy. The last runtime adjustment after `final-mobile` moves the same 50 ms constant to the shared module and adds the analogous opening-Garage adaptive scheduling; final component checks cover both renderer parsing and the final shared code.

The final Compatibility run completes all five opening laps with zero contacts and zero new draw pipelines during those laps. It also records a 778.960 ms Desert countdown hitch at tick 0/countdown 342. Reduced preparation intervals do not establish hitch-free countdowns or driving. Raw per-biome driving frames, pipeline deltas and contacts are retained in the integration JSON.

The eleven selected final-source receipts total **743 assertions, zero failures**, all exit 0, no text-source changes during any selected run and exact matches to the seven final runtime hashes. They have no engine warnings or script/shader/resource errors; the certificate-store environment error remains. `summary.json:selected_final` checks these conditions explicitly. The earlier Mobile full integration and archived lifecycle/Desert controls remain additional evidence with their source-revision and warning limits recorded separately.

Native exactness is tested on the **same target and scene**. Independent header controls already differ by a few channel bytes even when both use the archived implementation. Therefore the header fixture records independent-picture metrics, asserts byte equality across receipt publication on the same target and retains the existing authored `<0.02` normalized appearance limit. That appearance gate has not been relaxed. Independent ImageTexture readback equality is recorded rather than assumed.

Screenshots accompany the component, race, Garage, header, thumbnail and actual-entry label directories. `compare_pngs.py` is a read-only RGBA PNG comparator. Archived task-start sources are in `before/game/...`. Reproduction examples:

```powershell
python docs/evidence/graphics-preparation-2026-11-04/run_final_checks.py
python docs/evidence/graphics-preparation-2026-11-04/run_check.py final-components-mobile res://tests/test_shared_graphics_preparation.gd --renderer mobile
python docs/evidence/graphics-preparation-2026-11-04/run_check.py same-owner-race-final res://tests/test_shared_graphics_race_pixels.gd --timeout 300
python docs/evidence/graphics-preparation-2026-11-04/run_check.py final-mobile res://tests/test_shared_graphics_first_laps.gd --renderer mobile --timeout 600 --first-emission
python docs/evidence/graphics-preparation-2026-11-04/run_check.py world-lifecycle-control res://tests/test_shared_graphics_lifecycle.gd --verbose --control
python docs/evidence/graphics-preparation-2026-11-04/summarize.py
python docs/evidence/graphics-preparation-2026-11-04/checkpoint.py
```

Use a fresh label for further runs to preserve these receipts. The task-only checkpoint contains only this task's runtime/tests/report/evidence helpers, archived comparison sources and marker blocks. It is checked forward/reverse with exact normalized content in an owned build directory and never writes the main index.

## Failed experiments, environment and limits

- Initial primitive-mesh blend-shape introspection used an ArrayMesh-only API; corrected type guarding. A fixture then ran past its error and required stopping only its recorded, task-owned process tree. No owner process was changed.
- Initial component capture directory/counter issues and thumbnail one-shot scheduling included in the context were corrected. Scheduling/clear modes are excluded from the pipeline signature; real AA/pipeline settings remain included.
- An initial overstrict independent-header byte-equality test fails against the archived-before repeated control too. Raw attempts and metrics remain. Same-target native proof and the unchanged appearance gate replace that invalid assumption.
- An earlier interleaved profiler showed introspection overhead, leading to property-name caching and avoiding ShaderMaterial's dynamic uniform query. Its independent-picture assertions retain failures; it is not counted as a clean visual pass or used for the performance table.
- An earlier non-isolated Mobile integration reaches 134/0 assertions but leaks graphics resources at shutdown, so it is not presented as a clean run. The final isolated Mobile integration exits cleanly apart from the environment certificate error. The final lifecycle new/control pair both retain exactly the same two MP3 audio instances and one soundtrack resource at verbose shutdown, with no additional graphics leak. Causality for the earlier leak is not established.
- Windows engine logs report `Failed to read the root certificate store`; no backend request is enabled. Receipts retain these environment errors.
- Concurrent startup-shell and prepared-asset work changed App modules, build identity and baked assets during some earlier runs. Exact before/after text-source hashes and changed-source lists are retained. Final same-owner comparisons isolate the changed queue on identical scene IDs; claims here do not attribute concurrent startup/bake improvements to this task. Binary assets were not frozen for the whole session.

Reload/owner appearance acceptance and actual phone performance remain. No device query/test, APK/AAB, owner-save mutation, real authentication, live/backend request, deployment or main-index write was performed. This implementation targets repeated graphics preparation; genuinely cold compilation and the remaining startup/geometry/network costs require separate measurements.
