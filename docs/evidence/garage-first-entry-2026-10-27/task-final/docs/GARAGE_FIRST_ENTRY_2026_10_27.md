# Garage first-entry hitch reduction (2026-10-27)

The owner reports first-entry stutter, especially when entering immediately after launch, and selects keeping the menu available while Garage prepares during idle time. Preparation now begins earlier, visits more shader programs before repeating work, includes the career wall and prepares the selected carousel picture in the same original world. The main Garage retains its original saved appearance, lighting, glass, shadows, orbit camera and both live planar reflections. No photo covers the main view.

This reduces repeat preparation and late carousel work. It does **not** eliminate fully cold OpenGL shader compilation. The earlier 28-second figure came from an isolated, restricted, fresh shader-cache run; it must not be presented as the normal launch time or as a solved worst case. Normal driver-cache tests below are separate observations, not a cold-device guarantee.

| ID | Implemented behavior |
| --- | --- |
| GFE01 | Startup still does not await Garage. Native construction requires the first menu draw and 150 ms without deliberate input; GPU preparation requires 250 ms idle, replacing the earlier two-second delay. Existing foreground, transition, held-input, text-focus, race, account and memory fences remain. |
| GFE02 | Group StandardMaterial programs by modes, flags and texture presence rather than paint-material instance identity. Keep actual geometry formats, shadow modes, Shader identities and next passes in the key. Visit floor/car first and rotate among programs; retain the eight-object batch bound. Materials, shaders and geometry are not replaced. |
| GFE03 | Build the real career wall before warming. Capture the selected car's exact carousel pose offscreen in that same world, then restore the original camera, visibility, sampling and lighting before handoff. The matching saved paint/parts/condition picture transfers to the existing cache service. Partial adoption restores the live state immediately. |
| GFE04 | Custom carousel captures use the live Garage's key-shadow settings and 4x sampling. The v2 picture key separates them from old captures. A small renderer subclass lets the service schedule every draw after idle/input/navigation checks; each draw uses the original submit method to synchronize reflections. Other read-only showroom callers retain their defaults. |
| GFE05 | Regenerate all seven native Garage templates with the unchanged strict source guard. The initial Electric changes invalidated six templates; subsequent concurrent Compact changes invalidated all seven. Final resources match the current native builders, including that concurrent authored work. No model source is changed by this task. |
| R01 / Q01 | Actual App, saved-byte, viewport/input, exact-picture, reflection, stale-owner, partial-construction, cancellation and parser checks; native views and a scoped, reverse-checked patch. |

## Scope

Runtime changes are `game/core/app.gd`, `game/ui/garage_page.gd`, `game/ui/garage_preloader.gd`, `game/ui/garage_preloaded_studio.gd`, `game/ui/garage_preview_cache.gd`, `game/ui/car_showroom.gd` and the new `game/ui/garage_preview_renderer.gd`. App supplies the existing foreground/navigation gate. The page accepts the already prepared picture. The showroom's optional capture-lighting flag preserves its default behavior elsewhere.

The seven `game/assets/garage/cars_v1/*.scn` files are regenerated derivatives. Their current source hashes and the exact native-builder checks are recorded separately; concurrent Compact geometry is context, not an authored change by this task. Original reflection/shader/model/simulation sources, renderer selection, save formats and gameplay remain outside the runtime change. Concurrent App/account/physics/editor work is preserved in the checkpoint base. The preferred check's generated identity/version files are recorded separately and excluded from the source patch.

## Timing and its limits

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, RTX 3090 desktop, isolated test records and empty API URL. Timings start after App initialization/menu entry; they are not total executable-launch measurements.

| Observation | Result |
| --- | --- |
| Earlier two-second GPU-idle control, entry after 500 ms, normal driver cache | 91 ms callback; 1.067 s through the page transition |
| Earlier idle preparation, entry after 500 ms, normal driver cache | approximately 0.64–1.08 s through the transition in the recorded runs |
| Final fully prepared entry, normal driver cache | 84 ms callback; 0.325 s through the transition; no new selected-car capture studio |
| Same current assets and suite, old material-instance keys vs new feature keys | 114 vs 70 explicit warm draws headless; 69 in the final native ready trace |

The immediate-entry observations span different live desktop load and cache conditions. They do not establish a calibrated speedup or a maximum latency. A constructed but unfinished preload remains usable through the original live handoff; opening too early can still cause a visible native draw stall. Normal-cache runs also retain construction and capture intervals above a frame budget.

Restricted fresh-cache runs reached roughly 26–32 seconds through immediate entry; an exploratory run was longer under concurrent load. The normal-cache control was run outside the sandbox after transient class-cache errors were resolved. Driver caches were not cleared or exported. These results cannot identify a universally reproducible driver-cold time. Godot's [stutter documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html) explains that Compatibility needs actual first-use draws; its [pipeline documentation](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) distinguishes that path from the modern renderer's precompilation support. Fully cold compilation remains unresolved; no instant-entry, zero-hitch or phone claim is made.

## Verification

Actual commands, environments, return codes, source hashes, metrics, captures and the scoped checkpoint are in [report.json](evidence/garage-first-entry-2026-10-27/report.json). Use `python docs/evidence/garage-first-entry-2026-10-27/run_checks.py LABEL SCRIPT MODE` for the isolated runner.

- New first-entry checks: 24 headless, 31 Compatibility and 31 desktop Vulkan Mobile pass. These retain the original main render settings, all three viewports, the warmed career wall, exact saved paint/dirt, unchanged condition-file bytes, exact world adoption, input gates and restoration when entering during thumbnail preparation.
- The prepared photograph matches the actual v2 canonical renderer within the unchanged 0.01 mean-byte allowance plus measured repeat variation: approximately 0.000206 Compatibility and 0.003527 desktop Mobile. Both canonical repeats are recorded. Native images are retained.
- Retained preload suite: 399 headless checks pass. The same suite with only old key selection restored in isolated memory passes 399 checks and records 114 draws, compared with 70 for current keys. Current native templates pass all 28 original geometry/articulation/material checks. Actual App passes all 141 checks.
- The parser and preferred `dev.ps1 -Action CheckScript -ScriptPath res://core/app.gd` outcomes, and original reflection regression results, are recorded by the report compiler from their actual receipts.

The report retains initial failures and controls. The first picture-control fixture accidentally reused its PNG instead of forcing a second native render; the fixture now forces both controls through rendering. The first controlled-renderer version omitted reflection synchronization and failed the existing image allowance; using the original submit method corrects the reflection pose without changing that allowance. Transient concurrent class/account-lifetime errors and invalid inspection/CLI probes are not counted as passing checks.

Shared-finish shaders, broad PBR conversion, shader-cache disabling and lazy-shader experiments did not establish a sufficient, reliable improvement. They remain evidence-only prototypes; the lazy changes were restored exactly before final implementation. No prototype shader, alternate workshop or renderer configuration is selected by production. Failed task helpers were closed using exact task identifiers; owner processes were not stopped or restarted.

Reload and owner acceptance of immediate-entry feel remain. Physical-device latency, memory, appearance and touch acceptance remain untested; no device attachment query/test, APK/AAB, real authentication/purchase, owner-save/live backend mutation, deployment, main-index staging/commit/merge or owner-process restart was performed.
