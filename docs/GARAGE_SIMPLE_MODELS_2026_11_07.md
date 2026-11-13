# Simpler models in Garage — 2026-11-07

Garage now follows **Settings → Graphics → Simpler car models**. Apply the setting and return to Garage: the retained live showroom, car switching and carousel photographs use the selected model family. Turning it off restores the standard models. The setting remains off by default, and saved paint, parts, condition and camera framing are retained.

## Requirements and implementation

| ID | Delivered behavior |
|---|---|
| GSM01 | Initial, retained and replacement Garage cars inherit `reduced_car_models`; the same flag survives customisation replacements. Preloaded studio pins include quality and cannot transfer a mismatched studio. |
| GSM02 | Paint, fitted parts, orbit/zoom, exact condition snapshots, wash tools and both original planar reflections remain available on all five reduced cars. Cleanliness eligibility uses the standard exterior so changing render quality cannot relock a washed car. |
| GSM03 | Carousel requests, renderer creation, prepared-picture matches and background warming retain the selected quality. Reduced images have distinct keys, reject old completions and cannot reuse the standard catalogue photograph. The standard identity layout is unchanged. |
| GSM04 | Actual-App headless/native comparisons, washing and translation checks, guarded prepared-asset validation, explicit concurrent-source limits and a task-only checkpoint. |

Changed runtime files are `ui/car_showroom.gd`, `ui/garage_page.gd`, `ui/garage_preloader.gd`, `ui/garage_preview_cache.gd`, `ui/garage_thumbnail_studio.gd`, `ui/garage_cleanliness.gd` and the description in `ui/settings_page.gd`. All twelve descriptions are updated with exact UTF-8 round trips. No new preference, vehicle shape, physics setting, camera contract or quality threshold is introduced.

The Garage retains its existing half-pixel viewport/reflection policy. It uses the same lower-sampling model family and prepared reduced meshes as racing; projected detail selection still responds to the actual Garage view. This pass makes no tablet FPS, loading-time or memory claim.

## Washing safeguard

The reduced Kart exposed a real quality-dependent gate: leaving only the lowest wash-grid row dirty gave a clean standard car but a 26.687% missed fraction on coarse geometry, above the existing 25% limit. Four low rim samples were responsible. Increasing tolerances would change the accepted washing rules, so the limits remain unchanged.

For reduced rendering, the cleanliness inspector lazily samples a temporary standard rest-pose car with the same parts. It frees that reference synchronously and retains only the existing bounded point/scope/region arrays. It does not keep another showroom or draw another car. Actual wash interaction still targets the visible model, and existing wash coordinates and snapshots remain unchanged. Clean cars retain the zero-residue fast path. First dirty-car inspection can load standard meshes; additional device memory/frame cost is unqualified.

## Validation and pictures

| Check | Actual result |
|---|---|
| Latest integrated App / all-five Garage controls | 201 checks / 0 failures |
| Frozen native Compatibility | 241 checks / 0 failures |
| Frozen desktop Mobile | 241 checks / 0 failures |
| Cache quality isolation / specialized renderer | 46 checks / 0 failures |
| Reduced washing / underside / missed panels | 45 checks / 0 failures |
| Standard washing retained | 45 checks / 0 failures |
| Project-loaded description translations | 12 checks / 0 failures |
| Driving baseline / pinned entry point | 72 checks / 0 failures |
| Frozen prepared assets / photograph provenance | 468 resources; 1925/0; five pictures / 157 source hashes |

The primary fixture opens the actual App, applies the option through Settings, returns to the same retained Garage, and checks every stock/fitted vehicle in both qualities. Captures use normal zoom 1.0 and close zoom 0.52 with the original perspective camera. There are 40 final images per desktop renderer. Some near-limit close frames intentionally crop the car, as the ordinary zoom control permits; normal views show the complete vehicle.

[Garage comparison](evidence/garage-simple-models-2026-11-07/garage-comparison.png) and raw frames are retained with [summary.json](evidence/garage-simple-models-2026-11-07/summary.json). Comparison images are composed only from native screenshots. The desktop checks establish implementation behavior and reviewable appearance; owner/device acceptance remains.

## Source isolation and asset guards

The frozen library passes all 468-resource / 1,925 checks and five-picture / 157-source provenance checks with zero source changes during or after baking. The final native qualification uses that library. Matching live files were not substituted: later concurrent project, workshop, build and other source changes remain in the working tree. Frozen binaries and photograph provenance therefore stay separate, and this task provides a source-only review patch rather than claiming the entire live workspace is export-ready. A later integrated live-source App check passes all 201 checks. Exact qualified source versions are retained in `frozen-inputs/`; the complete isolated copy remains under `build/garage-simple-models-2026-11-07/frozen/`.

The first live pipeline found 130 stale Kart key/source checks and correctly rejected them. During that complete rebuild, a concurrent Kart tune changed again; the stable-source guard rejected the result. A selected repair subsequently passed all 468 resources / 1,925 checks and five photographs / 157 source hashes, with no changes during the repair. Later concurrent edits to Kart, `handling_config.gd`, `vehicle_simulation.gd` and project settings made live-source acceptance unstable again.

A separate frozen project is therefore used for final qualification. Generated assets and source files are independent copies; immutable asset/import data is reused, shader caches are private, and the source manifest is sealed against the live files at one coherent point. A copied index supplies original tracked-file names for build enumeration; the main index is never changed. The initial copy detected a project-settings change and was resealed. Git's cross-account ownership check initially rejected the task-created repository; a **process-scoped** `safe.directory` entry for that exact snapshot permits its build enumeration without changing global Git settings. Build identity generation updates only the expected project version/build metadata. Receipts pin the qualified inputs and outputs, including the controlled quality-refresh follow-up. No handling source is edited by this task.

## Commands and initial findings

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, through `scripts/run_no_crash_dialog.py`. The standard `scripts/dev.ps1` entry point runs the driving baseline. All engine profiles are task-private APPDATA/LOCALAPPDATA with an empty backend URL/config and Dummy audio. Native windows are off screen. Normal Windows execution is needed for the established sandbox certificate-store limitation.

Exact executable arguments, owned PIDs, duration and exit codes are retained under [commands](evidence/garage-simple-models-2026-11-07/commands/). Main scripts are `test_garage_simple_models.gd`, `test_garage_simple_cache.gd`, `test_garage_wash_surfaces.gd --simple-model` and `test_reduced_car_translations.gd`. Task runners and snapshot/asset recipes are under `build/garage-simple-models-2026-11-07/`.

The first combined appearance assertion failed because the fixture compared JSON schema version `2.0` against its normalized integer `2`; colours, pattern and stickers were identical. Final checks compare every normalized appearance field and preserve the initial diagnostics. The first purported close view used zoom 1.6, which actually moves farther away; it was rejected after image review and recaptured at 0.52.

The retained historical preloader suite stops at its assumption that a fresh loader with `foreground=false` should decode resources, then raises an unguarded dictionary access. The archived and current implementations reproduce the same foreground fence in the focused control. That broad historical suite is not claimed passed; quality-specific pins, cache lifecycle and actual retained Garage behavior are covered directly. Its exact task-owned process tree was stopped after the script error, and the partial log remains intact.

## Review checkpoint and limits

[task.patch](evidence/garage-simple-models-2026-11-07/task.patch) and [checkpoint receipt](evidence/garage-simple-models-2026-11-07/checkpoint-receipt.json) contain the scoped source/documentation/evidence change, checked in isolated forward/reverse applications. Concurrent sources and generated build identity are excluded; qualified asset ownership/adoption is recorded separately. The main Git index remains byte-exact. The Garage-page and catalogue baselines preserve concurrent changes; the patch contains only this task's additions and description replacement. Raw logs and unchanged frozen source archives remain available outside the patch, with exact receipts, reports and hash manifests included. The initial whitespace check flagged pre-existing formatting in three archived source files; their bytes are preserved rather than reformatted.

No device query/test, APK export/install, owner-save/process change, live/backend request, deployment or main-index write was performed. Reload/rebuild is needed to try the local change. Owner appearance acceptance and actual device input/frame/memory behavior remain unverified.
