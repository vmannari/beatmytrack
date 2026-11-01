# Road support reuse reduces repeat race loading — 31 October 2026

On the offline Star fixture, repeat race loading measured **1.928/2.057 seconds with support-cache eviction versus 1.056/1.156 seconds with reuse**. The average decreased from 1.992 to 1.106 seconds (44.5%). These are alternating runs in one actual App process on Godot 4.7.2, Windows Compatibility/OpenGL and an RTX 3090. Other road, world and shader caches remain warm in both cases. The control evicts only the new support cache; it retains the separate unused-outline optimization. This is a repeat-load measurement for one desktop track, not a startup, cold-driver or Android speedup claim.

Requirements and changes:

- **LTO01:** `game/track/road_surface_height.gd` no longer computes a rounded spline join whose output was discarded before building the actual swept support contours.
- **LTO02:** The new `game/track/road_support_cache.gd` retains exact numeric contours and spatial bins for at most four source-piece hashes and 2 MiB. It retains no track objects. Callers receive private polygon buffers and containers. In-place piece edits use a different key; terrain/car queries continue using the current track. The helper has no rendering dependency, runtime resource loading, file I/O or wall-clock access.
- **LTO03:** Two additions in `game/editor/editor_memory.gd` include the cache in the existing 64 MiB retained-memory accounting and release it alongside the road caches. A generation fence rejects work started before a pressure trim. The Star entry accounts for 148,712 bytes; this is a conservative retained-size estimate, not measured peak process or GPU memory.
- **R01:** `game/tests/test_loading_road_support.gd` and its frozen task-start constructor fixture compare complete data, boundary queries, mutation isolation, edits, entry/byte limits and trim behavior. `game/tests/profile_loading_support.gd` uses the existing timestamp-instrumented App probe for alternating cache controls and actual memory-pressure checks.

The final component regression passed **92 checks, zero failures**, comparing seven tracks and 46,746 boundary samples. Complete support contours, ordering, spatial bins and lift are byte-identical to the previous constructor. Eight interleaved Star samples measured a median **935.566 ms for the previous constructor versus 0.378 ms for cached construction**. Initial uncached Star construction in that run was 987.816 versus 825.638 ms; other cold samples vary, so the repeat result is the demonstrated improvement.

The actual-App run completed five races with zero recorded failures, preserving tick zero, the complete 360-tick countdown and five laps. It also verified retained-memory accounting and actual App pressure cleanup. First race loading was 10.143 seconds with already-used global driver/OS caches. The earlier multi-second cold shader/link bottleneck remains unresolved. This optimization adds no visual change and does not remove any covered graphics preparation.

The retained race-preparation regression passed **567 checks, zero failures**, including cancellation during preparation, metadata hydration, reusable roads, one loading cover, the full countdown and five-lap state.

The older road-height suite reports **120 checks / 16 failures** for current car handling and Desert expectations. A control restores the task-start support constructor and installs it on the suite's bridge objects: it reports the same 16 failure messages and identical driving measurement rows. This isolates support computation, not every historical project dependency; those unrelated assertions remain unresolved. The control source and generator are retained with the evidence. No failing assertions were weakened.

Initial findings are retained: restricted execution reached the component checks but failed the Windows certificate-store access check; normal-access offline runs completed. The first cache candidate exposed shared packed arrays and was corrected with explicit private polygon copies. An empty default-track fixture was replaced with the real Underpass fixture for entry-count coverage. A shared road-section-cache prototype was replaced by the pure numeric helper to keep rendering/resource loading outside canonical setup. An early eviction-order prototype lost the repeat speedup and was corrected before the final measurement.

Commands use a task-owned `APPDATA`, an empty `BMT_API_URL`, and `BMT_LOADING_OUTPUT` pointing into `docs/evidence/loading-optimisation-2026-10-31/`. Every noninteractive Godot process is under the crash-dialog wrapper, including the build entry point's version check:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_loading_road_support.gd
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_loading_support.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 240
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_road_height.gd
python docs/evidence/loading-optimisation-2026-10-31/make_height_control.py
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_loading_height_control.gd
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_preparation_reuse.gd
```

[Raw results and logs](evidence/loading-optimisation-2026-10-31/) retain the passing checks, failed attempts and interleaved timings. The task-only source patch excludes concurrent work and build-runner identity regeneration. No owner save, owner process, live service, deployment, main-index staging or commit was changed. No device query or Android test was performed. Reload/rebuild and owner/device loading acceptance remain.
