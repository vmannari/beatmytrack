# Ice lantern impact preparation — 2026-10-18

Owner report: “hitting the ice lantern cause a brief freeze”. ILH01 closes the missing first-use rendering preparation; ILH02 preserves actual breakup, rewind and retry; Q01 retains reproducible checks and their limits. G01/R01 preserve the existing art, camera, physics, saved data and unrelated concurrent work.

`game/vehicle/effect_render_preparation.gd` still allowed only wood/hay debris and the older Winter weather batches. The later Winter construction kit creates `SnowChunks`, `IceShards` and `SnowPowder`, but their zero-instance MultiMeshes were omitted from the covered race-loading draws. Loading their meshes/materials alone did not exercise those instanced draw paths. Ice uses a distinct transparent shader; powder uses a distinct shader and per-instance lifetime data.

The change adds those three existing names to the existing preparation allowlist. The original helper already submits one temporary instance using the live mesh, material, instancing format, camera and world, then frees it before the loading cover is released. No simulation, live instance buffer, shader, geometry, collision threshold, flame, lifetime, countdown, cache budget or gameplay draw population changes. This moves the previously uncovered rendering work into loading and can add cold loading work.

The new `game/tests/test_winter_break_preparation.gd` (+UID) uses actual `NativeTrackVisual`, `LightProps` contacts and the shipping App loading path with disposable offline data. It checks all five debris batches, real in-camera preparation, shared original resources, visible powder lifetime data, exact original buffers/counts, unchanged canonical snapshots and camera, byte-identical clean reveal pixels, actual destruction/flame removal, exact rewind/repeated impacts, retry cleanup, finite lifetime and cancellation after nodes have been freed. App reveal retains tick zero, the complete 360-tick countdown, five laps and no invented fragments or temporary preparation nodes.

The saved original helper reproduces four missing-coverage failures in each graphical renderer. This is a reproducible missing-preparation defect, **not a reproduction of the owner's freeze duration**. The desktop driver caches were retained, the host had concurrent work, and both original and final Vulkan samples reported zero new on-demand draw pipelines. The checks establish the added draw coverage and unchanged behavior; they do not establish a cold-phone frame-time improvement or prove this was the only cause of the reported pause. No physical-phone connection check/test, APK/export/install, backend mutation or deployment was performed. Owner confirmation on the affected device remains.

| Actual check | Result |
| --- | --- |
| Saved original, Compatibility, components only | 48 checks, 4 expected missing-coverage failures |
| Saved original, desktop Mobile/Vulkan, components only | 51 checks, 4 expected missing-coverage failures |
| Final focused, headless, including App | 42 checks, 0 failures |
| Final focused, Compatibility, including App | 64 checks, 0 failures |
| Final focused, desktop Mobile/Vulkan, including App | 67 checks, 0 failures |
| Existing Winter construction, contacts, five-car driven replay, fragment budgets | 595 checks, 0 failures |
| Existing breakable props | 46 checks, 0 failures |
| Existing dynamic preparation, headless | 148 checks, 0 failures |
| Godot import | Passed |
| Full script compilation after import | 896 scripts, 0 failures |

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, Windows, NVIDIA RTX 3090. Desktop Mobile/Vulkan is a desktop renderer check, not a phone measurement. Final isolated ice-lantern fixture observations were 2.094 ms contact / 0.540 ms presentation / 2.232 ms wait to one rendered frame in Compatibility, and 1.141 / 0.218 / 1.077 ms in Vulkan. These are diagnostic samples, not whole-race timings, FPS claims or a before/after speedup.

Reports and native captures are in [the evidence directory](evidence/ice-lantern-hitch-2026-10-18/). In each graphical folder, `intact-before.png` and `intact-after.png` have identical pixel data; `ice_lantern-broken.png` retains the original shatter effect. The `.txt` original helper is loaded only by `--original`; shipping sources are never swapped to reproduce it.

The initial restricted runs could not write the default Godot user log or initialize Windows certificate access. Tests subsequently used workspace-local `APPDATA` and approved local execution. An initial direct script call also encountered PowerShell's execution policy; actual engine invocations used the established `-ExecutionPolicy Bypass` entry point. Early full focused attempts failed only the new App fixture: its new `automatic_scenery` key was created as a StringName through dictionary dot assignment, while the authoring validator requires String keys. The fixture now uses the same explicit string key as the existing Winter tests, with its explicit ground paint. Production validation was not changed. The first broad parser attempt encountered the missing temporary `res://tests/review_rivalry_entry_before.gd`; a normal import refreshed the index and the unchanged full parser passed. Initial failures remain separate from the final results.

Actual engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with `$env:APPDATA` set to the workspace's `build/ice-lantern-tests/userdata`. For the two-argument original comparisons, PowerShell `-Command` passes the array directly:

```powershell
scripts/dev.ps1 -Action CheckScript -ScriptPath res://tests/test_winter_break_preparation.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_break_preparation.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--original','--components-only') -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_break_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--original','--components-only') -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_break_preparation.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_break_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_break_preparation.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_craft.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_breakable_props.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_dynamic_render_preparation.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

The five headless regression commands were invoked sequentially by `powershell -NoProfile -ExecutionPolicy Bypass -File build/ice-lantern-tests/run_regressions.ps1`. That wrapper's repeated action shares its log filename, so the individual 42/595/46/148 outcomes are retained in the tool transcript and summarized here; the final focused JSON and dynamic-preparation JSON also retain their corresponding results. Original comparison logs, the retained final Vulkan log, import/parser logs, source hashes and the task-only patch are copied into this task's evidence. The first successful Compatibility log was subsequently unavailable in the shared build-log directory; its 64/0 JSON and tool output remain.

Changed files: the preparation allowlist, the new focused test/UID, this report, and the task notes prepended to `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. The source-only [task patch](evidence/ice-lantern-hitch-2026-10-18/task-only.patch) is the reviewable checkpoint. Shared Git HEAD/index and unrelated changes are preserved.
