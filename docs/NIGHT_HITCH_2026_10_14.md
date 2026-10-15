# Night first-use hitches, 2026-10-14

The owner's current PC game (PID **19920**, started **21:12:47 Helsinki**) captured Easy night / Compact / Compatibility / RTX 3090, kit198 and physics0.58. The local file `race-1792001705-19920-2419928861447.json` contains **eight** driving events and no dropped events or contexts:

| Driving time | Observed interval | Render boundary |
| ---: | ---: | ---: |
| 0.725 s | 101.867 ms | 94.674 ms |
| 1.175 s | 155.141 ms | 145.827 ms |
| 1.758 s | 140.428 ms | 133.016 ms |
| 3.167 s | 153.318 ms | 143.049 ms |
| 3.300 s | 129.738 ms | 118.444 ms |
| 3.433 s | 137.511 ms | 127.186 ms |
| 4.233 s | 110.997 ms | 96.725 ms |
| 6.333 s | 458.944 ms | 443.738 ms |

Most of each stall lies between render signals; this is wall time, not GPU execution time. The largest event has 12.978 ms of physics and 0.781 ms of presentation. All eight have zero condition-save time, no telemetry writer/editor worker/recovery callback and no active cloud operation. One event has 0.162 ms of recorded cloud IO. Weathering, tire and effect preparation are already true. There are **no bridges or hazard meshes** to prepare. The shared covered preparation took 9,579.66 ms before the countdown. Smoke/clipping/mud masks change around some later events, so those observations alone cannot exclude dynamic effects.

The old 5 Hz context associates several events with first terrain/road section candidates, but its **128-mesh inventory omits 200 meshes**. The 6.333-second event's last context is before the stall and the next sample is after it; candidate timing alone cannot identify the native call. Compatibility's pipeline counters are unsupported and remain zero.

The public cached Easy night document was copied into ignored `build/night-hitch-2026-10-14/track.json`. Its compiled geometry hash matches the live capture exactly: `9762bcaabbc226d7f18e45769207f9e8bcd0d43e82041cc7ce0de2189e03a391`. An isolated graphical probe freezes simulation, countdown and condition, uses disposable records, and moves only its presentation through public route regions corresponding to the captures. The first pass peaks at **239.019 ms** between render signals; repeating the same regions peaks at **8.279 ms**. The terrain shader identified by hash `e71bb35a…` is shared by **70 meshes using one Shader RID and one material RID**. Two road-role shaders are each shared by 29 meshes. Thus this probe does not support blaming duplicate terrain shader creation.

Godot Compatibility selects shader specialization flags according to whether a geometry instance has Omni or Spot lights; it binds the matching shader variant at draw time. Light counts themselves are uniforms, so the lead is **presence combinations**, not recompilation for every numerical light count. This explains how preloading a material or rendering it only in the starting light context can still miss a later variant. [Pinned GLES renderer source](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/drivers/gles3/rasterizer_scene_gles3.cpp), [Godot compilation guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

The diagnostic preparation submits the existing visible geometry through four bounded covered contexts: neither local light type, Omni only, Spot only, and both. It preserves the actual camera, meshes, materials, transforms and original light properties. Temporary cull margins include the current camera; two tiny, shadow-free temporary lights there provide the presence combinations while original Omni/Spot visibility is temporarily suspended. All visibility and culling values are restored before uncovering the scene. The test uses **307** existing geometry instances. The four preparation steps take **14.510 / 474.977 / 777.664 / 130.613 ms** in this run, and the subsequent first-region pass peaks at **8.269 ms**; the repeat peaks at **8.468 ms**. Expensive work is moved into loading.

These are sequential shared-desktop runs with evolving driver caches, not paired cold-cache FPS measurements. The exact native stack for the live 443.738 ms render boundary was not obtained. The reproducible first-region delays, shared shader identity, renderer variant selection and successful preparation identify a missed Night light-context path; they do not prove every recorded event has that one cause or promise generally hitch-free racing.

Production integration is **Night + graphical Compatibility only**, including GLES phone builds when subsequently exported. It uses the existing loading cover and bounded render waits, with at most four contexts for the current finish and four more if restoring a clean finish exposes different car shader RIDs. The original finish/bridge/hazard/personal-ghost/tire/effect preparations remain. Existing geometry/material resources are reused; no racing draw, permanent light, texture or geometry cache is added. Limits are **1,024 geometry instances / 64 original local lights**. Geometry truncation is recorded; exceeding the light bound aborts before changing the scene. Source tire geometry, shading, pressure, encoding, sampling and the full 16,384-slot ring are unchanged.

The observational `night_preparation` capture records completed contexts/sets, item count, elapsed time and bounds/abort status. Mesh descriptors add session-local Shader RIDs and original shader resource paths when fixed-role source metadata exists, within the original four-material-role cap. The inventory still represents initial bindings, not every later cosmetic swap or a native GPU program ID. Existing event/file/byte limits and local-only persistence remain.

Navigation during the longer covered sequence exposed a frozen prepared scene left behind when the loading cover was closed. After restoring all temporary state, `_start_race` now releases only its same still-disabled scene on that cancellation path. It preserves a replacement or already-running game. Actual navigation cancellation is checked; this cleanup finding is not attributed to the original driving stalls.

Actual validation: Night preparation **19 Compatibility / 14 Mobile-Vulkan / 13 headless checks**; exact restored framebuffer bytes, camera, canonical state, condition, geometry/material bindings, lights, culling/visibility and original tire buffer/cursor are retained. Actual App reveals tick0 and all360 countdown ticks, records eight weathered/clean contexts on Compatibility, releases temporary nodes and handles navigation cancellation. Mobile/Vulkan and headless skip the new preparation. Hitch capture **47 headless / 47 Compatibility** checks the new markers, shader bounds and full eight-event file cap. All **758** current scripts parse. Existing non-Night loading **26 headless / 27 graphical** checks pass on final runs.

Commands through the pinned entry point:

```powershell
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_night_first_use.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_night_first_use.gd -Graphical -TestArgument '--warm'
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_night_render_preparation.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_night_render_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_night_render_preparation.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd -Graphical
```

Initial issues are preserved: a concurrently added CompactFrontLamps class was initially absent from the class cache; the explicit import then failed because a running Godot process held the audio extension's temporary DLL, after which the running editor registered the class. The new test used an incorrect tire-buffer property and initially omitted the existing published-track prerequisite; both fixtures were corrected without relaxing assertions. Navigation cancellation revealed the frozen-scene cleanup issue and was fixed. Optional shader metadata needed `has_meta` guarding because a null default still emitted an engine error. A Mobile run completed all14 assertions but hung during shutdown and hit the existing300s command limit; its isolated90s-limit retry completed successfully. The non-Night graphical check encountered a mesh-normal construction error before Game's ready marker, and its retry hit an API mismatch while the records menu was being concurrently edited. A later full-parse run encountered a non-static reflection call in that new records test, corrected by the concurrent work; no mesh-builder or records-menu source was changed by this task, and the final current parse and graphical regression pass.

Evidence, paired images, probe JSON, source snapshots, command logs and the scoped review patch/hash manifest are under `docs/evidence/night-hitch-2026-10-14/`. Concurrent track-loading packets and Compact-model/menu work are preserved and excluded from this checkpoint. No user game was restarted or terminated, no driver cache was cleared, and no phone command, APK export/install, full Validate or backend deployment was performed. Restart the PC game to load the preparation and expanded capture. Owner repeat races on Easy night, a matching native trace for any remaining stall, and physical-phone validation remain outstanding.
