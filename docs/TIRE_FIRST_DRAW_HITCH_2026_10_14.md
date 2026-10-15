# First tire draw phone stall — 2026-10-14

The owner requests a fix for the remaining first tire draw stall. The fix prepares one temporary ribbon through the actual race camera while the loading cover remains up. The DN2103 cold pass then records no100ms racing hitch; the previous974.903ms tick86/route3 event does not recur. The tested APK is installed. This is a first-use preparation result, not a paired whole-build FPS improvement or a claim that every hitch is eliminated.

Requirements: **TFH01** prepare the actual tire draw before racing; **TFH02** preserve the parallel tire renderer, full ring, artwork, condition, camera and canonical behavior; **TFH03/Q01/V05/G01/R01** record actual renderer/device checks, restoration, limitations and a scoped checkpoint.

The preceding [hazard investigation](DESERT_HITCH_INVESTIGATION_2026_10_13.md) captured the974.903ms event on APK0B5C4045. Its render boundary was952.473ms, while measured callbacks took2.248ms, and native stacks contained `cmpbe_v2_compile_multiple_shaders` in the Mali GLES driver. The trail cursor changed4→12 around its first MultiMesh frustum candidate. A candidate alone does not establish an actual GPU draw.

This pass first used that **same installed APK**, same original Desert document and an empty app shader cache with the existing `trails` diagnostic feature. The one-second event disappeared. That feature hides tire presentation **and also skips `SkidTrails.sample`**, because the game guards sampling on visibility. It is component isolation, not a render-only or identical-work comparison. Other graphics remain enabled; the diagnostic reduction does not ship. The native compiler evidence and the following successful actual-draw preparation support the first-use rendering diagnosis.

Compatibility requires a mesh to reach a real rendering frame during loading to prepare its shader; preloading the resource alone is insufficient. [Godot pipeline compilation documentation](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html). A one-slot MultiMesh retains the live format/color/custom-data flags; the GLES renderer derives its instancing flags separately from draw instance count. [Godot GLES renderer source](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/drivers/gles3/rasterizer_scene_gles3.cpp).

`game/vehicle/trail_render_preparation.gd` shares the **exact live ArrayMesh and Shader RID**, duplicates only preparation material uniforms, and creates one temporary MultiMesh slot in the actual camera frustum. An unparented one-slot `SkidTrails` encoder calls the existing `_mark` implementation, so the parallel packed layout, surface style and pressure encoding remain authoritative. Its uniforms use the actual starting surface/track bridge configuration. No source shader, tire mesh or live ring is replaced or sampled for preparation.

`game/core/app.gd` submits that temporary draw together with the existing covered finish/bridge/hazard draw and frees it before uncovering the race. Cleanup also handles a deleted game. `game/core/game.gd` and `game/diagnostics/race_hitch_monitor.gd` retain one observational `trails_prepared` flag. There is no persistent preparation cache or added racing draw. The existing one MultiMesh,16,384-slot ring, four-wheel sampling, endpoint history, original dust and canonical simulation/scoring remain intact. `skid_trails.gd` SHA-256 remains `865fd46227f0e794d4d18231a8d45553b78b0ea3874482bf13156099bfb904e4`; `trail_visibility.gd` remains `08dbc5684a07b2cd44fc6b5d08eef7cca7636b1eae6f89065ffe180e384a3b2c`.

The new `game/tests/test_trail_render_preparation.gd` exercises Pine, Winter and Desert against real native scenes. It proves the temporary ribbon produces pixels, shares the live mesh/shader/instance format, and leaves the complete original GPU buffer, CPU ring arrays, cursor/history, material/uniforms, canonical state, condition and camera unchanged. Teardown restores **byte-identical images** on both renderers, leaves one original tire batch, and preserves16384 capacity. Normal covered App startup reveals tick0 and all360 countdown ticks with no fabricated marks. Hidden/headless paths and deleted-node cleanup are checked. [Actual outcomes](evidence/tire-first-draw-2026-10-14/checks/outcomes.json) and [Desert restored capture](evidence/tire-first-draw-2026-10-14/gl_compatibility/desert-after.png) are retained alongside all six before/after pairs.

| Actual check | Result |
| --- | --- |
| Tire preparation, Compatibility |38 checks,0 failures |
| Tire preparation, Mobile/Vulkan |38 checks,0 failures |
| Tire preparation, headless |26 checks,0 failures |
| Existing covered loading/cancellation |27 checks,0 failures |
| Existing bounded hitch monitor |45 checks,0 failures |
| Android quick validation |Pinned import/APP_READY, Driving72, Catalog21, Menus48 pass |
| Final shared script parse |714 scripts,0 failures |

Initial failures are retained under `checks/initial-failures`: a test-only extra parenthesis, restricted engine user-cache access, and the typed cleanup argument rejecting an already deleted batch. Cleanup now accepts a Variant and checks validity before freeing; the cancellation assertion is retained. The graphical rerun used the normal permitted engine cache. Only the verified process tree of this task's failed sandbox test was stopped; an unexpected reused process ID was preserved. No unrelated process was stopped.

Actual phone: **OnePlus DN2103, Android13, Mali-G77 MC9, GLES3.2 Compatibility**, pinned Godot4.7.2 `ed1daf0bf`. The original private track document retains canonical hash `3c4040753a9955a17cab387bd18b5a1bb0912d361e6a1d7501ce71d95cfcbe75`. Normal0.667 world scale,2x MSAA, actual camera, shadows and billowing dust remain enabled. The fix APK SHA-256 is **`310E3647FE2B97EA23F5D2E8DA2C07544987AEBFF973A34B3574903F1D01CFA6`**, frozen at `build/tire-first-draw-2026-10-14/tire-prepared-09/installed.apk`, installed with `adb install -r`, and independently hash-checked on the device before/after tracing. No uninstall/data clear/reset/security or clock change was issued.

| Instrumented group | Sample duration after5s warmup | Largest measured cold / primed frame | p99 cold / primed | Distance cold / primed |
| --- | ---: | ---: | ---: | ---: |
| Same old APK, tire component hidden / `tire-hidden-08` |30s |29.534 /34.097ms |23.091 /22.497ms |240.082 /240.618m |
| Fixed APK, **drawing and sampling enabled** / `tire-prepared-09` |60s |50.414 /49.175ms |22.886 /23.250ms |533.313 /533.484m |

Both fixed passes complete with zero paused frames, nonzero actual tire sampling cost (~0.18ms mean) and696 conservatively visible tire instances at the final snapshot. The live capacity remains16384;696 is the draw view, not a reduced ring. These are game-observed intervals under native tracing, not independent display cadence or a controlled speedup percentage.

The first tire draw occurs within the warmup, so the measured60s maxima alone cannot validate it. The separately running bounded hitch logger captures that phase: **the fixed cold pass has no100ms event anywhere after race preparation** and native Android logs contain no `RACE_HITCH`; the primed pass has one **117.380ms at tick0/countdown346, cursor0**, before any tire mark. It reports `trails_prepared=true`,28 parallel prepared particle emitters and194.054ms for the shared covered draw. That countdown event precedes system-trace scheduling coverage, so it is not given a native attribution. No first-tire movement hitch is recorded in either fixed pass. No precise tick86 frame time is claimed without a retained per-frame history.

Both final local traces retain ~12,000 PID-filtered native samples and report zero buffer overwrites. They report the existing `ftrace_setup_errors=51` notice and9/10 discarded chunks, plus small ELF/map/unwind errors. The evidence establishes the recorded stall's nonrecurrence, not absence of every compiler call or a full GPU timeline. The earlier hidden cold sample still logged203.420ms at tick36 and206.402ms at tick192 outside its measured window. Other first-use resources remain separately owned work.

The fixed APK contains contemporary parallel loading/ghost/effect and other workspace work. Preserve those changes; this pass does not claim their improvements. Current source subsequently adds the parallel impact-canvas preparation and an extra validity guard at the tire cleanup call; the tested tire helper itself remains exact. No paired isolation of the entire old/new APK, long thermal session, Winter phone run or owner visual acceptance is claimed.

The trace helper preserved the original known shader cache and restored **every original cache-file SHA** for both groups. The hidden group's record files were absent and their absence was restored. Before the fixed group, normal app operation had created both record files; both SHA hashes were restored exactly. Diagnostic markers, private document and backup names were removed, and the normal app relaunched. Generated diagnostic shader caches remain under explicitly task-owned names; no player cache was deleted. Raw traces, full logcat, APK and private fixture stay local under ignored `build/`. No competitive ticket, score write, backend or production deployment occurred.

Actual commands used `powershell -NoProfile -ExecutionPolicy Bypass -File` for PowerShell helpers:

```powershell
scripts/trace-desert-phone.ps1 -Mode ColdPair -RunName tire-hidden-08 -Seconds 30 -Features trails -DocumentFile build/desert-hitch-2026-10-13/original-desert-document.json
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_trail_render_preparation.gd -Graphical -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_trail_render_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_trail_render_preparation.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd -Graphical -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
scripts/trace-desert-phone.ps1 -Mode ColdPair -RunName tire-prepared-09 -Seconds 60 -DocumentFile build/desert-hitch-2026-10-13/original-desert-document.json
python scripts/analyze-desert-hitch-trace.py build/desert-hitch-2026-10-13/tire-prepared-09/cold.pftrace docs/evidence/desert-hitch-2026-10-13/tire-prepared-09 --stage cold --tick 86
python scripts/analyze-desert-hitch-trace.py build/desert-hitch-2026-10-13/tire-prepared-09/primed.pftrace docs/evidence/desert-hitch-2026-10-13/tire-prepared-09 --stage primed --tick 0
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 240
```

One analysis invocation mistyped `--stage` as `-Stage`; argparse rejected it without processing, and the corrected command completed. The isolated review checkpoint is `build/tire-first-draw-2026-10-14/checkpoint-repo`, with its [manifest](evidence/tire-first-draw-2026-10-14/checkpoint.json) and [task-only patch](evidence/tire-first-draw-2026-10-14/task-only.patch). Concurrent runtime is baseline context; only this task's preparation/observation hunks enter the change. Main Git index/HEAD were not mutated by this task. Full Validate was not run; no canonical contract was changed. Remaining acceptance is ordinary owner driving/quality review, other independent startup hitches and wider device/thermal coverage.
