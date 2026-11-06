# Menu shell and deferred feature loading — 4 November 2026

The App now opens its initial account menu without loading the native Race scene, Editor controls/world, Garage page/showroom or car renderer. The existing App scene, navigation state, service ownership and callback API remain the entry point. Feature composition lives in separate controllers loaded on demand.

Requirements: MSH01 shrink the initial dependency graph; MSH02 preserve navigation, ownership and asynchronous lifetimes; MSH03 retain screens, saved appearances and authoring/race behavior; MSH04 compare measured startup and native output; MSH05 retain commands, failures, limits and a task-only checkpoint.

## Measured startup

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, Windows, RTX 3090, Compatibility, 1280×720, Dummy audio. The control is the recorded task-start App implementation. Both implementations use the same frozen supporting scripts and prepared assets, with private profiles and an explicit empty backend configuration.

| Scenario | Task-start App | Menu shell |
| --- | ---: | ---: |
| Stock profile, App resource load, sample 1 | 12.201 s | 2.441 s |
| Stock profile, App resource load, sample 2 | 13.278 s | 3.344 s |
| Stock profile, engine initialization to first menu draw, sample 1 | 16.044 s | 6.215 s |
| Stock profile, engine initialization to first menu draw, sample 2 | 17.255 s | 9.336 s |
| Customized car, persisted header picture, first menu draw | 12.106 s | 4.913 s |
| Customized car, missing header picture, first menu draw | 24.244 s | 22.556 s |

The stock runs were interleaved control/candidate/control/candidate in fresh processes. The two customized scenarios are one seed/reuse pair per implementation; admitted header writes finish outside the timer. Cached runs each observe one disk hit and zero header captures. Missing-picture runs each capture the exact equipped car once. All eight runs exit zero, drain admitted header writes and have unchanged recorded sources/assets within their run.

The initial menu is still gated by an exact customized header on a miss. That renderer is required to retain the saved design: the new seed spends 15.855 s in initialization, compared with 11.419 s in the control, because work formerly paid in the eager resource graph is now incurred by that necessary render. Total first draw improves only modestly in that one uncached customized sample. This implementation does not remove first-use 3D work.

These are small shared-desktop observations, not a statistical percentage guarantee, cold-driver benchmark, packaged startup, signed-in network measurement or Android prediction. Engine-age timestamps exclude OS process creation. The earlier review's 8.8–9.0 s graph measurement describes its older supporting-code snapshot; the matched control above was remeasured after concurrent asset/rendering changes. Do not compare the new graph against that earlier number as a controlled before/after test.

The timing snapshot precedes the final controller lifetime binding and cheap keyboard/cancellation guards. Those do not admit feature code during startup. The final fresh-process timing observes the first menu at 5.151 s, including 1.959 s App resource loading, with all optional resources still cold; final source updates and per-run hashes are retained rather than presenting every diagnostic as one identical whole-tree revision.

## Architecture

`game/core/app.gd` retains account restoration, shared chrome, navigation state, scope/generation fences and the existing callback names used by menus and subclasses. Its first use of a feature loads that feature's script, creates one nonvisual controller as an App child and caches it. Controller methods receive the same App owner and operate on its existing state; they do not create a second profile, cloud client, record store or simulation. Domain parameters retain their types inside the controllers.

The controllers are separated into Race installation/results/retry, Free Race browsing, selected-track preparation, Rivalry, Challenges, Daily, Settings, Creator landing pages, the native Editor and Garage. Free Race no longer imports Rivalry's podium presenters just to build a browser, and the biome picker no longer imports the full authoring canvas. Game's PackedScene is a lazy resource too.

Controllers are App-owned Nodes with ordinary `run_*` methods. This makes suspended feature work share App's teardown lifetime and avoids registering those methods as automatic engine input/process callbacks. Existing signal callbacks and virtual dispatch remain bound to App through its facade. The editor worker uses an already bound controller rather than loading/mutating the feature-resource dictionary from the worker. Focused teardown checks release an App during the first actual race-entry yield and while a real editor worker is active.

The lightweight header widget no longer declares its native `ProfilePreview` class. The unchanged renderer/factory lives in `ui/profile_car_renderer.gd`, loaded for a missing customized image. Existing factory API methods delegate to it, preserving camera, lighting, paint, stickers and fitted parts. Stock and cached headers continue to use pictures.

The Garage preloader is a lightweight coordinator. It waits for the first menu draw and reuses car-presentation code after a real feature has loaded it; an idle account screen does not pull that graph in. Explicit Garage entry can still obtain its picture pool immediately and retains the existing loading ghost and full live studio. Public scene/PNG reads retain their existing workers. GDScript compilation stays on the owning thread; an experimental threaded script-loading path was removed after teardown errors and an incomplete overlapping-entry run.

`core/app_memory.gd` is a lazy boundary to the existing memory policy. It retains the 64 MiB shared retention and 96 MiB optional Garage allowances and delegates accounting/pressure cleanup when native features exist. The policy is activated with native feature controllers. No memory-budget increase, measured RAM saving or FPS gain is claimed.

Idle service callbacks stay in the shell. In particular, account keyboard navigation does not load the editor, empty selected-work cancellation still increments the original generation and clears its fences, and pending authoring writes still flush through the editor when needed. The localization extractor now scans the controller directory: all **3,179 message keys and plurals** match the task-start corpus.

The runtime uses normal GDScript/resource loading; the extraction scripts in the evidence directory are one-time audit tools, not runtime code generation. The existing `all_resources` export policy includes the new controllers. No export preset, engine version, physics/rules version, quality setting, camera, geometry, texture, shader or animation design was changed by this task.

## Behavior and visual checks

Fresh-process cold-start checks query `ResourceLoader.has_cached()` at the first account menu, exercise Tab navigation and empty cancellation, and check idle callbacks. Native Race, all optional controllers, Editor canvas/world, Garage page/showroom and car renderer remain unloaded; the optional native memory policy has not been constructed.

The twelve accepted frozen runs total **546 checks / 0 assertion failures**, all exit zero with unchanged per-run recorded sources/assets: cold shell22, actual App141, startup music37, Daily17, race loading187, controller lifetime/write flushing13, customized header24+23, original/Compatibility/Mobile flows24 each, and populated offline Rivalry10. The existing actual-App integration, startup music, Daily elimination and race-loading suites pass on the frozen project. New native flows exercise Free Race, prepared Race entry at canonical tick zero with all 360 countdown ticks/five laps, complete Editor construction and undo, complete Garage construction with both planar reflections, retained Garage return, and owner-change release. Compatibility and desktop Mobile each pass the flow's assertions. Rich customized-header seed/reuse checks retain saved paint, sticker and kit, independently rendered reference comparisons, zero wrong visible frames and zero new captures on restart.

The final full-frame comparisons preserve exact decoded pixels for Account, Free Race, Race and the prepared Editor. An initial Garage comparison mixed background-prepared and direct-entry lifecycles and differed in five pixels, maximum channel delta 53. A matched cold-entry pair reduces this to five pixels with maximum channel delta **1/255**. A repeat of the original App itself varies in three Garage pixels by the same maximum 1/255, while its other four views remain exact. The strict five-view pixel comparison therefore remains **4/5 exact**, not a five-view pass. All original reflections, workshop objects, materials, camera controls and carousel pictures remain present. Raw images and exact comparison results are retained; owner appearance acceptance remains.

The broader legacy `test_menu_page_swipe.gd` produces **162 checks / 75 failures** with this implementation and the exact same 75 failure labels with the task-start App restored in memory. Both retain the obsolete `GarageCircuit`/missing-tween errors. This is not an accepted passing suite, and its assertions were not removed or weakened. A separate headless delayed-membership Rivalry fixture did not complete and was stopped; its initial profile-containment rejection and later incomplete run remain recorded. Neither is counted as a pass.

An initial new Rivalry screenshot probe had no seeded offline competition and correctly found no podium/track rows; the explicit sample-data follow-up passes ten native checks with populated podium/track rows and the Race, Editor and Garage resources still cold. No real authentication or live competition was used.

## Isolation, commands and retained findings

The shared workspace received concurrent prepared-asset and graphics changes during early checks. Primary comparisons use a task-owned project copy: mutable scripts, UI assets and prepared scenes are copied, while unchanged static/imported assets and native libraries are shared through recorded local junctions. Source/asset hashes are recorded before and after every primary run. The frozen-project manifest records all copied hashes, shared directories and later explicitly copied task-owned fixes. No shared asset was modified through those junctions.

Examples from the workspace root; use new labels/profiles for reruns:

```powershell
python docs/evidence/startup-shell-2026-11-04/freeze_project.py
python docs/evidence/startup-shell-2026-11-04/run_batch.py timings
python docs/evidence/startup-shell-2026-11-04/run_batch.py owned
python docs/evidence/startup-shell-2026-11-04/run_review.py visual-cold-control res://tests/test_startup_shell_flow.gd --frozen --before --cold-garage --timeout 300
python docs/evidence/startup-shell-2026-11-04/run_review.py visual-cold-candidate res://tests/test_startup_shell_flow.gd --frozen --cold-garage --timeout 300
python docs/evidence/startup-shell-2026-11-04/run_review.py pixels-compat-cold res://tests/compare_startup_shell_views.gd --frozen --headless visual-cold-control visual-cold-candidate
python docs/evidence/startup-shell-2026-11-04/check_copy.py
python docs/evidence/startup-shell-2026-11-04/dependency_graph.py
python docs/evidence/startup-shell-2026-11-04/summarize.py
python docs/evidence/startup-shell-2026-11-04/checkpoint.py
```

The runner invokes the pinned engine through `scripts/run_no_crash_dialog.py`. Records, library, cloud cache, backend configuration and image caches are private. Commands and owned process IDs are recorded; failed/stalled test trees were stopped using their checked task-owned PIDs, including scoped elevated cleanup after restricted Windows process termination was denied. No owner process was stopped.

Iterations remain visible: extraction qualifier/type/parser mistakes, initially eager service callbacks, an initially wrong EditorWorld base type, an unused publication-dialog type mismatch, the removed threaded-script experiment, an invalid flow fixture ID, a capture before Editor preparation finished, a missing header evidence directory, and the broad swipe/Rivalry findings above. Corrections retain the original behavioral assertions. The missing-directory header attempt was repeated with a fresh private profile and precreated output directories, not accepted as a pass. Native/headless logs retain the Windows certificate-store environment error; stock boot probes, including the final cold-shell diagnostic, retain the already observed two-instance/one-resource teardown warning. This is retained rather than called a clean environment log; the final explicit race/editor controller lifetime test passes.

The repository-wide localization checker still reports its existing stale/obsolete/untranslated catalogue failures. A task-scoped before/after extraction comparison proves no lost/added message keys or changed plurals; the catalogue failures were not repaired or suppressed by this task.

## Files and acceptance

Changed runtime: App composition, Garage preload coordinator, header widget/factory split, the menu swipe gesture capability boundary and the tutorial's equivalent 2D-to-world coordinate conversion. Added runtime: `core/app_memory.gd`, `core/features/*.gd`, `ui/profile_car_renderer.gd`. The only authoring-tool change is the localization source glob. Diagnostics, evidence tools, this report and concise repository tracker entries form the remainder.

The task-only source patch is checked forward/reverse and for content equality in an owned directory. Its tracker base removes only this task's unique marker, retaining concurrent tracker changes. Prepared assets, rendering helpers, generated build identity/project-version edits and unrelated work are excluded. No main Git index staging or commit is performed.

Reload/rebuild and owner appearance/input acceptance remain. Representative Android cold/warm startup, signed-in session/network timing, all first-use graphics contexts and physical-device memory/thermal/input performance are unmeasured. Feature code is deferred rather than eliminated, so the first visit still pays necessary feature loading and native preparation; repeated scenes/picture caches continue to work. No physical-device query/test, APK/export, owner-save/process change, live/backend operation or deployment was performed.
