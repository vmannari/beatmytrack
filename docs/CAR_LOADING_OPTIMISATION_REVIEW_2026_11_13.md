# Car loading optimisation review — 13 November 2026

The next pass should reduce the resources and script dependencies loaded for a
race, then reduce the stored mesh payload. Further distance LODs alone will not
make the first race substantially faster: their extra index buffers are still
loaded alongside the close mesh.

This is a review with disposable, in-memory prototypes. No production model,
cache, runtime source or picture was authored. Challenger remains excluded.
Concurrent changes from other work were preserved.

[Machine-readable summary](evidence/car-optimisation-review-round2-2026-11-13/summary.json).

## Actual loading observations

The profiler enters the actual App, uses private offline records, starts an
ordinary five-lap practice race, retries it, leaves, then enters again. The
loading cover is released with tick zero and the full 360-tick countdown.
Backend URL/auth are empty; audio uses the dummy driver. The selected vehicle's
prepared base is audited only after both measurements, to avoid preloading it.

Eight clean fresh-process commands cover all five stock cars in Compatibility,
fitted Rally in Compatibility, Rally on the Star fixture in desktop Vulkan
Mobile, and Kart in desktop Vulkan Mobile. They finish **44 checks / 0 failures**,
with **16 race entries and 16 retries**. Each entry records a prepared-base hit;
all post-timing base key/source/structure audits pass. All 21,573 pinned vehicle
source/asset/configuration and Git-index inputs are unchanged during these eight
commands. This guard does not cover the entire App source tree.

These are desktop RTX 3090 observations with existing OS/import/driver caches,
not Android timings or a controlled cold-cache before/after benchmark. First
means first race in that process. The profiling work did not clear owner caches.

| Actual case | App ready* | First race | Repeat entry | Car setup first / repeat |
|---|---:|---:|---:|---:|
| Rally, Compatibility, ellipse, traced | 2.204 s | 7.194 s | 294 ms | 57.5 / 10.0 ms |
| Kart, Compatibility, ellipse | 2.098 s | 6.645 s | 331 ms | 52.5 / 10.5 ms |
| Forklift, Compatibility, ellipse | 2.149 s | 6.470 s | 278 ms | 52.8 / 8.6 ms |
| Volt, Compatibility, ellipse | 2.113 s | 6.096 s | 270 ms | 50.3 / 7.7 ms |
| Hover, Compatibility, ellipse | 2.035 s | 5.733 s | 188 ms | 46.7 / 6.3 ms |
| Rally, four fitted categories, Compatibility | 1.972 s | 5.962 s | 297 ms | 66.6 / 21.2 ms |
| Rally, Star, desktop Vulkan Mobile, traced | 1.980 s | 16.079 s | 671 ms | 205.2 / 63.5 ms |
| Kart, ellipse, desktop Vulkan Mobile | 1.980 s | 7.682 s | 573 ms | 131.5 / 38.8 ms |

*App ready measures scene load through startup completion after profiler setup;
it excludes engine/process boot and is separate from race entry. Fixture
read/compile is also measured separately. Cases differ in renderer, track,
parts and cache history; these rows are not renderer or car speed rankings.
Retries reuse the installed Game and take 8.5–11.3 ms in the clean commands.

`car_us` covers creating/restoring the car and its finish bindings. It does not
include loading the enclosing script graph, later first-use draws or shared
weathering/effect preparation. Therefore it cannot be used to label all the
remaining time as unrelated to cars.

The first Rally observation took 22.940 s, with 101.979 ms in car setup and a
1.738 s maximum covered draw. It is retained as a diagnostic, excluded from the
clean table: 344 vehicle-cache inputs changed concurrently, and teardown left
one resource in use. Later runs use corrected test cleanup. The initial Vulkan
attempt lacked the fixture's offline version pin and installed no race; its
failure is also retained and excluded.

## Highest priority: load only what this race uses

**CLR01 — Stop eagerly loading the full Kart driver/helmet for other cars.**
`kart_driver.gd` contains literal resource preloads at lines 63 and 69, reached
through the shared procedural construction graph. In actual Hover, fitted Rally
and Star Rally observations these resources are absent at App startup and
present after the first race, although Kart is not selected. Their measured raw
mesh streams total **1,057,116 B**: driver 905,304 B and helmet 151,812 B. This is
not a process-RAM, VRAM, compressed-file or time saving measurement.

Use lazy, selected-vehicle resource loading for these original factory assets.
A valid prepared race should load its own assembly without bringing in unused
procedural model assets. Keep full-detail authoring/Garage references available
when actually requested. For Kart, its selected driver remains necessary; the
full original helmet should not be loaded just to use its reduced counterpart.

**CLR02 — Separate prepared-car restoration from the large factory script
graph.** `VehicleModels.build` preloads multiple model constructors, and
`CarVisual` references the fallback generation and kit systems even on a
successful base restore. Merely putting a `preload` inside a branch does not
defer it. Keep the lightweight prepared loader/material rebinding path separate
from optional source constructors, with string-based lazy dispatch for the five
target vehicles. Preserve strict source/key rejection and the complete fallback;
Challenger's model and behaviour remain outside the change.

The App's measured first-use feature intervals include `editor_memory.gd`
at **2.436–2.884 s** in the clean commands, race feature loading at
0.608–0.684 s, and Game scene loading at 0.665–0.757 s. These are observed feature
wall intervals, potentially overlapping other work, not additive isolated car
costs. They justify tracing and separating dependency graphs before doing a
large additional polygon cut. Model edits alone cannot promise removal of the
whole first-entry wait.

## Smaller prepared geometry, baked before loading

**CLR03 — Share identical immutable meshes between repeated parts.** The review
finds exact encoded duplicates whose active surface materials are independently
overridden. They can keep separate wheel/steering nodes while referencing one
mesh. The key checks all encoded mesh streams, metadata and bounds; meshes with
morphs or a separate shadow mesh are excluded.

| Car | Prototype active buffers | With exact sharing | Potential raw saving |
|---|---:|---:|---:|
| Rally | 1,115,156 B | 1,000,808 B | **114,348 B** |
| Kart | 1,762,174 B | 1,692,166 B | **70,008 B** |
| Forklift | 1,712,852 B | 1,712,852 B | 0 B in this conservative search |
| Volt | 965,196 B | 846,252 B | **118,944 B** |
| Hover | 609,776 B | 593,496 B | **16,280 B** |

Total candidate saving is **319,580 B across the five assemblies**. These are
procedural-fallback candidate measurements from the earlier inventory, taken
during concurrent cache regeneration; they are not the current prepared-scene
totals or an additional delivered saving. That inventory records ten concurrent
Electric kit writes. All normal loading runs above subsequently hit valid bases.

Do this sharing in the offline bake. Loading duplicate meshes and swapping them
at runtime has already paid their file/resource/upload costs, and the PackedScene
may continue retaining the originals. Native scene compression can already
compress repeated bytes, so disk-size and loading-time savings must be measured
after rebaking. Existing fixed-part batching is already implemented; another
blanket merge would not address this remaining resource duplication.

**CLR04 — Split static Kart suit faces out of the steering morph mesh.** The
prototype compares raw position and normal/tangent records across all ten poses.
It finds 1,615 fully invariant suit vertices and 2,761 completely static suit
triangles. Gloves remain animated; mixed static/moving triangles remain in the
animated mesh. It copies referenced encoded records without re-encoding them.

The measured driver payload becomes **905,304 → 583,776 B**, a potential
**321,528 B / 35.5%** saving while retaining all 6,456 driver triangles and all
ten pose names. It adds one static surface/draw. Only the raw-data prototype and
triangle preservation check have run: steering interpolation, native pixels,
contact/clearance and the load-time/draw tradeoff still require qualification.
The original eager preload must also be removed from the normal race path;
otherwise adding the split resources can increase total loaded data.

## Material preparation and further race-only detail

**CLR05 — Reduce unnecessary material/vertex-format variants.** Keep distinct
paint, glazing, lamps, tyres and moving parts, but seek equivalent static finish
configurations that can use a shared shader feature set. Changing colour or
roughness as a uniform does not by itself justify another feature variant.
Preserve live lamps, weathering, livery projection, shadows and night contexts.

In the traced Compatibility Rally entry, six draws containing only held car
geometry occupy 153.109 ms; two mixed car/world draws occupy 133.604 ms. In the
Star Vulkan observation the corresponding intervals are 36.284 and 9.631 ms.
These include frame scheduling and previously visible work, not isolated GPU
compile costs or a predicted saving. Shared finish/effect preparation is measured
separately and also includes particles/canvas work. The trace does not justify
attributing the entire first-race wait to car shaders.

**CLR06 — If more reduction is needed, bake a genuinely smaller race asset.**
Use a race-specific close mesh with fewer redundant inner wheel/fixture surfaces,
tiny stacked trim faces and round-fixture samples, selected by projected error
in supported race cameras. Rally/Volt repeated wheels are the first candidates;
Kart retains the requested arm motion and Hover retains fan/skirt silhouettes.
Keep separate Garage close-detail assets. Bake the smaller vertex streams into
the race resource rather than loading the full mesh and selecting a short LOD
index list afterward. No numerical triangle target or invisible-detail claim is
qualified yet; require native moving/night/shadow comparisons first.

The duplicate-LOD-index search found no saving in the measured assemblies. More
ordinary distance LODs can add loaded bytes, as the previous Volt/Hover pass
already demonstrated. Triangle count should remain a secondary acceptance metric
for this loading-focused work.

## Next implementation and acceptance

1. Implement CLR01/CLR02 first: avoid unselected factory resources and isolate
   the prepared loader. Keep missing/stale-asset fallback and all five stock and
   fitted construction paths working. Do not weaken provenance guards.
2. Bake CLR03 sharing and qualify native pixel identity, articulation and
   per-instance material isolation. Measure full loaded dependency bytes as well
   as the active mesh payload.
3. Prototype CLR04 and CLR05 separately. Retain each only if its measured loading
   or retained-memory benefit outweighs additional draw/setup work. Pursue CLR06
   after this evidence, with a projected-error budget agreed through appearance
   comparisons.
4. Compare App-ready, first race, same-track re-entry and retry for stock/fitted
   cars with identical renderer, track, cache state and launch sequence. Record
   cache hits, unselected resources, main-thread stalls, shader draws and full
   selected-car dependency bytes. Verify visible appearance, livery, night lights,
   wash, moving driver, wheel/fan articulation and unchanged driving/configuration
   sources. Device loading/appearance testing remains a separate qualification.

The next pass should be judged by reduced time to drive and bytes actually loaded,
not by a lower triangle number alone.

## Reproduction and retained evidence

`scripts/run_car_optimisation_round2.py` supplies the private profile, source pins,
owned-process timeout and empty backend environment. For example:

```powershell
python scripts/run_car_optimisation_round2.py load-kart-compat --script=res://tests/profile_car_race_loading_round2.gd --rendering-method gl_compatibility -- --car=kart
python scripts/summarise_car_loading_review.py
```

`--fitted` selects the first non-stock option in each of four categories;
`--star` selects the Star fixture. `--trace` adds timers to the loaded
`world_render_preparation.gd` resource **in memory only**, without altering its
algorithm or source file. Trace rows retain complete source paths so concurrent
background Garage draws are excluded from race-car attribution.

The earlier raw-buffer inventory is reproduced with the runner's default script
and `--headless`. It finishes 1 check / 0 failures; visual candidate captures have
not been run. Source manifests, original failed diagnostics, logs, per-case timing
JSON and command receipts are retained under the linked evidence directory.
Identical source manifests are deduplicated during closeout; their original
hashes remain referenced in the receipts. Automatic approval review blocked
recursive removal of this task's temporary build folder, reporting only
"blocked by policy". Its active-work marker was removed successfully, and the
owner-requested build-retention command ran successfully. Approximately 79 MB of
temporary private profiles/output remain under
`build/car-optimisation-review-round2-2026-11-13`, subject to normal retention;
they were not moved into permanent evidence. The standard cleanup retains recent
work and reports about 24.27 GiB of total build output, above the 20 GiB target.
No export, device query, APK, deployment or main-index staging occurs.
