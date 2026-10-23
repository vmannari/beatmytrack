# On-device race preparation — 2026-10-18

DTL01 ports the measured Desert deformation bottleneck to native device CPU code. DTL02 prepares finished road arrays before their first GPU upload and prepares Winter cover off the main thread. DTL03 prepares only the settled selected track and hands that work to Race. DTL04 keeps idle memory and persistent device storage bounded. G01/R01/Q01 retain original appearance, canonical racing and reproducible validation. This follows the owner's rejection of server-side visual packs and authorization to implement the device approach.

## Result and measurement boundary

The Windows prototype produces exactly the original final mesh arrays in twelve independent mesh/transform cases, including coloured geometry and nonuniform transforms. It retains the original GDScript path when the extension is unavailable or disabled. Mid-subdivision cancellation discards partial output. Android ARM64 and x86-64 libraries compile, export the entry point and have 16 KiB ELF load alignment; this is not phone execution.

The original-versus-device rendered fixture compares the same track document, two simultaneous viewports and the same lighting/camera. Its original path uses raw road packets and the frozen original Desert deformation; the new path uses the production CPU road job and finished arrays. Compatibility observations:

| Fixture | Original road preparation + world construction | Device path |
| --- | ---: | ---: |
| Desert Star | 44.687 s | 15.978 s |
| Desert bridge | 15.144 s | 4.275 s |
| Pine Star | 5.886 s | 6.000 s |
| Winter Star, before moving cover | 12.775 s | 12.904 s |

These are desktop fixture timings, not end-to-end race starts or phone measurements. The original runs first in each pair; the second can benefit from shared asset, auxiliary and OS caches. HTTP/tickets, track compilation, complete Game setup, shader/driver preparation and countdown are outside these intervals. The focused native loop comparisons independently show approximately a tenfold reduction on the tested planes. Pine and Winter road-generation algorithms remain unchanged; no general speedup is claimed for their total CPU work.

The earlier stage-attribution review on the same Star fixture recorded roughly 24 s for the separate Desert deformation pass. A native-only integration observed 2.807 s for that pass, with the original geometry signature. CPU-finishing the road packets then left 0.330 s of scene deformation in another run. Those stage samples are from separate process checkpoints and are not a paired whole-loading benchmark.

The oversized prepared-road regression restores 37,082,424 estimated resident bytes from a 7,222,863-byte local artifact in 121.36 ms. Its guarded copy of the production loader proves that no regeneration occurs. This is a fresh loader invocation sharing OS caches, not a cold-storage or phone guarantee.

## Implementation

`native/track_geometry/track_geometry.cpp` implements the original subdivision, field sampling, attribute interpolation and normal transformation using typed native values. It preserves Godot's `SurfaceTool` encoding and indexing, the scalar/vector precision boundaries, original thresholds and recursion order. Floating-point contraction and fast-math are disabled. There is no new per-frame calculation or canonical dependency. The optional adapter is `game/track/geometry_acceleration.gd`; unsupported platforms use the original implementation.

Desert road preparation now performs its original intermediate normal/colour encoding in CPU arrays, applies deformation there, and tags the finished arrays. Installation uploads the finished mesh once; the later relief pass recognises it. Remaining terrain, finish, bridge and prop presentation still use the original relief rules, accelerated where applicable. This is a finished-road path, not a claim that every world mesh has become a single-pass builder. Visual kit 210 fences the changed prepared artifacts; physics/rules/compiler versions are not changed by this task.

Winter cover/marker placements are computed during the existing road job and reused by installation. Selected-track preparation also supplies cover when existing roads already reside on disk. Cover is kept out of the road-only CPU LRU because its placement depends on the complete track, including objects and paint. Shader/materials, populations, original joins, bridge layers, Desert recess and all original driving data remain.

After a selected detail has settled for 650 ms, the browser requests preparation. Hidden page previews, the full track list, moving views and unresolved selections do not start geometry work. The App checks browser/selection serial, object identity, content/version pin, car, navigation, account/origin scope and safety. It downloads the normal hash-checked document if needed, compiles and prepares on the existing tree-owned worker, and validates scope again before publishing results. Obsolete work is cancelled and reaped; new selected work waits for cancelled work to finish instead of accumulating warm jobs. Pressing Race while the matching preparation is active waits for and consumes it under the existing loading cover. The same selected object is hydrated, with tick zero, the complete countdown and five laps retained. The warmer does not issue race tickets or leaderboard writes.

Prepared CPU arrays too large for the 32 MiB shared CPU/GPU road LRU are staged as private, compressed local numeric arrays. Only the current main-thread scope can publish them. They share the existing road cache's eight-artifact/96 MiB disk limits, 32 MiB compressed file limit and 96 MiB expansion bound. Content/engine/visual/format identity, checksum and packet structure are checked on read; object deserialization is disabled. A completed GPU road artifact replaces its CPU representation. Cancelled staging files are removed. The 64 MiB prepared-world LRU is unchanged. These are existing accounting estimates and bounds, not measured peak process RAM.

Everything runs on the player's device using existing track-document endpoints. There is no server bake, visual-pack endpoint, new provider or backend deployment. Downloading the selected document earlier can use bandwidth for a track the player ultimately does not race; it does not download a server-generated mesh pack.

## Validation

Observed successful checks, with retained command logs and final counts in [report.json](evidence/device-track-loading-2026-10-18/report.json):

| Check | Result |
| --- | --- |
| Native geometry, cancellation and GDScript fallback | 30 checks, zero failures |
| Selected preparation, actual race handoff, content/car/account/navigation fences, delayed document response and teardown | 59 checks, zero failures |
| Oversized local geometry, shared budgets, exact restore and regeneration guard | 9 checks, zero failures |
| Compatibility original/device geometry, shader parameters, render flags and exact pixels | 12 checks, zero failures |
| Updated Winter cover, Compatibility | 3 checks, zero failures |
| Desktop Mobile/Vulkan geometry, material parameters and exact pixels | 12 checks, zero failures |
| Existing App | 140 checks, zero failures |
| Existing driving / rewind | 72 / 61 checks, zero failures |
| Existing prepared worlds / road cache / race preparation | 85 / 70 / 17 checks, zero failures |
| Existing editor placement, retained geometry and cancellation | 185 checks, zero failures |
| Project script compilation | 875 scripts, zero failures |

Desktop Mobile is a renderer check, not Android execution. Captures show the actual original/device scene pairs, not generated mockups. No phone FPS or eliminated-shader-stall claim is made.

All engine work uses pinned `scripts/dev.ps1`, with disposable workspace `APPDATA`. Principal executed commands:

```powershell
scripts/dev.ps1 -Action BuildTrackGeometry
scripts/dev.ps1 -Action Import
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_device_track_geometry.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_device_race_preparation.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_device_road_spill.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_device_geometry_views.gd -Graphical -RenderingMethod gl_compatibility
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_device_geometry_views.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--winter-only'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_device_geometry_views.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
scripts/dev.ps1 -Action TestApp
scripts/dev.ps1 -Action TestDriving
scripts/dev.ps1 -Action TestRewind
scripts/dev.ps1 -Action TestRoadCache
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_preparation_reuse.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_placement_latency.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

The first C++ compile used an operator not exposed by the existing bindings; using their `xform` API corrected the build. Initial delayed-response fixtures omitted the real client's scope/capability members and failed in existing lifecycle/discovery code. The final fixture subclasses the actual adapter, overriding only its transport and startup, and passes the same invariants. No shipping assertion was removed or weakened. Final logs are retained separately from those attempts. Several independent functional checks ran concurrently; their incidental timing rows are not used as performance guarantees.

## Review checkpoint and remaining acceptance

Runtime changes: `game/core/app.gd`, `game/ui/track_browser.gd`, `game/race/selected_track_preparation.gd`, `game/editor/road_preparation.gd`, `game/track/native_track_visual.gd`, `desert_road_relief.gd`, `geometry_acceleration.gd`, `winter_scenery.gd` and `road_mesh_disk_cache.gd`. Native source, build helper, three platform binaries, GDExtension descriptor/UID, licence notice and Android filters complete packaging. Four focused tests/UIDs, this report/evidence and AGENTS/status/plan entries form the rest of the slice. Native provenance and MIT notice are in [PROVENANCE.md](../native/track_geometry/PROVENANCE.md).

The [task-only patch](evidence/device-track-loading-2026-10-18/task-only.patch) and isolated Git bundle contain this slice, including binaries. Unrelated publishing-slot, Rivalry/profile, checkpoint and backend work remains in the shared tree and is included as baseline context rather than changes in this checkpoint. The isolated review repository contains selected files, not a complete executable checkout. No broad shared-tree commit or reset is performed.

Physical Android execution, appearance/feel, peak RAM, storage eviction, thermal behaviour and owner acceptance remain. Native shaders/driver compilation and other-biome road generation can still dominate first use. Native binary rebuilds add platform build maintenance. No phone attachment check/test, APK/export/install or live backend/deployment action was performed.
