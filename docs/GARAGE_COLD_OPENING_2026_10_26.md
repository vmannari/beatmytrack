# Responsive Garage opening (2026-10-26)

The owner still found Garage slow after the preceding menu work. The clarification is authoritative: live 3D is preferred, but responsiveness matters and the user should not have to wait. This change opens the ordinary Garage page before constructing or drawing the native workshop. A stock photograph covers the first frames, then a live version of the actual car and room takes over with simpler temporary finishes. Orbit and the existing tools work during preparation; the original finishes and both reflections replace the temporary rendering when ready. No loading page, progress copy or extra confirmation is added.

| Requirement | Implemented behavior |
| --- | --- |
| GCO01 | Navigation creates the page and seven nonblank cards immediately; studio construction runs after the page opens. Seven public catalogue photos decode through threaded resource requests after menu startup, independently of any Garage world. |
| GCO02 | Preserve live geometry, orbit, camera, fitted parts, paint/stickers and wear. Appearance/Parts can open before full finishes finish preparing. Earlier deferred tool intent is cancelled by a later Cars click. |
| GCO03 | Seven native rest-pose resources avoid repeated procedural car construction. Meshes remain shared, mutable paint materials remain owned, and stale source/configuration or unsupported kit combinations fall back to the existing builder. |
| GCO04 | Native material batches wait for 750 ms without input and pause while hidden. Latest car/paint/parts requests replace older targets. Retained page transfers keep the same studio; owner replacement/destruction releases its jobs, geometry, lights and viewports. |
| R01 / Q01 | Exact model/material comparisons, actual App navigation, early-tool checks, native screenshots, isolated persistence and a scoped review patch. |

## Measurements and limits

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, desktop RTX 3090, 1280×720, isolated profiles and no API. Fresh shader caches and repeat-cache runs are distinguished in each command record. The live-readiness scenario deliberately leaves for Settings and returns; its live/full-preparation times include that navigation. These are desktop measurements, including the renderer named Mobile; they are not phone measurements.

| Actual App, fresh shader cache | Navigation callback | First page image | Live view ready | Maximum measured active orbit frame |
| --- | ---: | ---: | ---: | ---: |
| Compatibility | 68 ms | 482 ms | 2.45 s | 16.7 ms |
| Desktop Mobile | 68 ms | 866 ms | 6.07 s | 9.7 ms |

The task-start attribution run returned from synchronous construction in 1,160 ms and spent another 29,922 ms on its first native draw. Removing the sky or reflections alone did not solve that cold stall. Prepared stock geometry reduced an attributed car-build stage from about 716 ms to 34 ms in comparable warmed-cache diagnostics. These attribution runs differ from the final page-level measurements and are not a controlled phone benchmark.

The page and navigation no longer wait for the full studio. First-use live 3D still takes time, particularly with a completely fresh Mobile shader cache. Full preparation in the final fresh runs took roughly 26 s Compatibility / 10 s desktop Mobile while the page was present, with idle-frame spikes of 1.78 s / 0.61 s. A synchronous driver compilation already in progress cannot be cancelled when input arrives. This is a substantial entry improvement, not a guarantee of hitch-free or instantaneous live rendering. The retained ready studio is reused on later visits.

Godot documents first-use rendering stalls and the different pipeline strategies available to renderers: [jitter and stutter](https://docs.godotengine.org/en/4.5/tutorials/rendering/jitter_stutter.html), [pipeline compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html). The measured result above, rather than general engine documentation, is the evidence for this implementation.

## Implementation and ownership

Runtime scope is `core/app.gd`, `ui/garage_page.gd`, `ui/car_showroom.gd`, `ui/garage_preview_cache.gd`, a render-only opt-in in `vehicle/car_visual.gd`, and four new Garage helpers: `garage_car_cache.gd`, `garage_opening_showroom.gd`, `garage_first_draw.gd`, `garage_opening_facade.gd`. Seven native `assets/garage/cars_v1/*.scn` resources accompany the helpers. The stock catalogue PNGs are unchanged.

The opening uses actual mesh geometry with shared temporary shaders; it keeps livery/sticker/wash formulas and existing paint/kit sweep code. It restores the original materials instead of saving or replacing them. Uniform copies use the temporary shader's declarations. Sweep progress is copied just before drawing because tweens advance after node processing. Car copies retain exact local transforms; room copies belong directly to the studio world and follow original global transforms and parent visibility. Camera movement does not rescan the geometry. Body picking builds triangles lazily and excludes temporary copies.

The full studio and both reflection targets use matching MSAA during preparation. A temporary 64×64 view draws bounded groups of original finishes on a separate layer; full materials do not enter the active camera while preparing. Native target/canvas settling precedes the first accepted drag. Native carousel captures wait until the main studio is ready, keeping their existing one-renderer and 14-file limits. The temporary view, geometry and lights are released afterwards, leaving three steady studio viewports. A separate temporary carousel renderer may still exist while an exact saved-appearance photograph is being captured.

Prepared-car provenance is in `game/assets/garage/cars_v1/provenance.json`. The baker serializes the current original model rest poses, including material-role ownership. ImmediateMesh surface arrays must be converted to ArrayMesh before saving: Godot does not serialize the immediate draw commands. Source hashes/configuration keys guard local development; unsupported/stale resources retain the old builder. Re-run the baker and exact seven-car comparison before exporting changed model sources. Export/device behavior was not exercised here.

Concurrent purchase-dialog, profile/header, Rivalry, parking-hall, model, handling and race preparation changes remain intact. In particular, the concurrent configurable car-build budget is excluded from this patch. Canonical simulation, handling resources, input mappings, economy and save formats are outside this task.

## Verification

Actual commands, environment, exit status and raw output are recorded per run in [the evidence directory](evidence/garage-cold-opening-2026-10-26/report.json). The repeatable command is `python docs/evidence/garage-cold-opening-2026-10-26/run_checks.py LABEL SCRIPT MODE`. It invokes the exact pinned console build, a disposable `APPDATA`, dummy audio and an empty API URL. `BMT_CACHE_PROFILE` explicitly reuses a disposable shader cache; omitting it gives each label its own profile. The preferred `scripts/dev.ps1` entry had already been attempted in the preceding menu task and stopped on this sandbox's certificate-store error; the pinned executable fallback is retained. That certificate error is listed separately from test failures.

- Focused actual-App opening: 195 headless / 199 fresh Compatibility / 199 fresh desktop Mobile checks pass. The final native fixtures wait for the actual incoming Garage picture and assert that construction has not started when it draws.
- Exact prepared models: 28 checks pass across all seven cars, comparing node paths/matrices, surface arrays, stored material values and texture bytes, wheel articulation and independent paint ownership.
- Early paint/Parts: 2,504 headless / 2,505 Compatibility / 2,505 desktop Mobile checks pass, including exact source transforms, current sweep uniforms, newly fitted rear aero, record artwork replacement and destruction while preparation is paused.
- Retained carousel: 38 headless / 47 Compatibility checks; retained mobile-audit 253 headless / 266 Compatibility checks pass. The main-studio readiness wait replaces assumptions that the live studio exists synchronously. The original whole-page three-viewport assertion remains at a capture-idle boundary, alongside a new exact main-studio count.
- Actual App: 141 checks pass with clean cleanup after the room ownership fix. All 1,318 scripts parse; final run results are recorded in `report.json`.

Initial failures are retained: invalid in-memory profiling injections; unconsumed threaded-load references; missing serialized ImmediateMesh surfaces; a reference fixture that omitted the Garage caller's default livery; eager cold material exposure; the first accepted drag preceding native target settling; a Mobile callback over 250 ms before photo prefetch; one-frame sweep uniform lag; room-copy shutdown leaks; a matrix round trip introducing tiny wheel-transform differences; a whole-page viewport assertion observing an intentionally active temporary carousel capture; and an early screenshot still showing the outgoing Race page. Native construction now waits for the incoming picture to draw after the menu slide, and first-page measurements use that actual Garage frame. Fixes preserve the original 250 ms callback and 150 ms active-orbit bounds, exact geometry/material comparisons and resource limits. The retained carousel fixture also stops its own music after startup loads settings, resolving an audio-only shutdown warning; production audio is unchanged. No pixel tolerance was relaxed. Broader swipe/hero-title failures documented by the preceding menu task were not rerun or represented as passing here.

Native captures include the first page, the early live view with Parts, the early painted car with fitted wing, and the settled original studio. They are evidence of rendering, not owner visual approval.

Reload/rebuild and owner acceptance of entry latency, appearance, touch/controller behavior and phone performance remain. No attachment check or physical-device test, APK/AAB, real authentication/purchase, owner-save/live backend mutation, deployment, Git staging/commit or owner-process restart was performed.
