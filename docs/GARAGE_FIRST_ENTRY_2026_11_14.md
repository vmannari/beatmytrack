# Garage first entry — 2026-11-14

The first Garage now decodes the reduced car base and the owner's selected kit modules that its actual restoration path consumes. It previously decoded a full-detail Garage rest scene that reduced cars always reject. Shader preparation checks the scheduled groups instead of rehashing the entire remaining queue on each draw. Every candidate still gets a current key before submission/reuse and a fresh validation after the awaited draw. Completed captures share material-key work within their synchronous validation pass. Native warm draws no longer add a second frame wait after `frame_post_draw`; headless preparation still yields, and the complete live view and both reflections still settle before reveal.

Requirements: GFE01 correct prepared inputs; GFE02 bounded key work with unchanged mutation/cancellation guarantees; GFE03 draw scheduling with original appearance/reflections/input gates; GFEV01 native integration and measured first entry.

Three interleaved before/after pairs used the same 320 watched source/prepared inputs, with no changes during any run. Each process had disposable offline App storage. The baseline loads the four retained task-start scripts in memory; it uses the same current assets as the corrected implementation.

| Compatibility, first live Garage | Before | After |
| --- | ---: | ---: |
| Pair 1 | 1,736.756 ms | 1,564.376 ms |
| Pair 2 | 1,968.753 ms | 1,726.302 ms |
| Pair 3 | 2,041.825 ms | 1,838.274 ms |
| Median | 1,968.753 ms | 1,726.302 ms |

The median improves **12.31%**. One desktop Vulkan Mobile pair improves 2,505.031 to 2,289.023 ms; this is a single sample. The prepared reduced base is actually used in both controls. Reentry retains the same studio and takes a few milliseconds. Separate diagnostic instrumentation measures scheduled key work at 201.476 versus 48.812 ms; those exploratory samples are not the final latency comparison.

First-use stalls remain: Compatibility maximum frames range 266.947–293.485 ms before and 245.840–352.798 ms after; the Vulkan pair retains approximately one-second maximum frames. There is no demonstrated improvement in worst-frame latency. These are Windows/RTX 3090 samples with existing project/driver shader caches, not a cold-driver, physical-phone, FPS or hitch-free result.

Initial 3.65–3.94 second runs rejected the prepared base because `car_mesh_lods.gd` had changed. Concurrent publication repaired that source receipt while this task ran. The controlled comparison above excludes that change, and this task does not claim the full initial-to-final improvement. No vehicle geometry, prepared binaries or identity files were authored by this task.

Validation completed:

| Check | Actual outcome |
| --- | --- |
| Prepared paths and before/during/pending/context mutation cases | 122/0 native Compatibility; 122/0 headless |
| First live original finishes, both reflections and orbit | 18/0 Compatibility; 18/0 desktop Vulkan Mobile |
| Deferred paint/parts, original transitions and destruction | 16/0 each desktop renderer |
| Retained Garage, input/owner/appearance/pressure/cancellation checks | 439/0 native Compatibility |
| Shared render preparation/capture/invalidated receipt checks | 168/0 each desktop renderer |
| Actual App entry and same-studio reentry | All six current cars; fitted Rally and Challenger retain all four requested modules |
| Worker read completion/failure/destruction | 29/0 headless; expected injected resource errors retained |
| Production parser | 568/0 |
| Python compilation and scoped whitespace check | Pass |

The retained suite's resource-only fixture now names the actual reduced base and explicitly enters the presentation-script-ready phase before suppressing native construction. Its ownership/readiness/visibility/input assertions remain. The two initial fixture failures and their stopped task-owned processes are recorded. An experimental persistent material-key cache was rejected after four regression failures showed that StandardMaterial3D edits do not synchronously emit all expected change notifications. The final implementation uses fresh validation and has no persistent material cache. Early fitted-profile setup ran before App loaded its records; rejected selection checks are retained, and the corrected fixture seeds only its private records after that load. A shared-render test first lacked its required output environment variable; its script error and successful configured reruns are retained. No failed or stopped attempt counts as a pass.

Changed production files: `game/ui/garage_studio_assets.gd`, `garage_opening_showroom.gd`, `garage_preloader.gd`, `garage_first_draw.gd`, and `game/rendering/graphics_preparation.gd`. Tests/tooling: `game/tests/test_garage_entry_assets.gd`, `profile_garage_first_entry.gd`, the retained fixture above, their new UID files, and `scripts/run_garage_first_entry.py`. [Machine-readable receipts and source hashes](evidence/garage-first-entry-2026-11-14/report.json), [watched comparison inputs](evidence/garage-first-entry-2026-11-14/paired-inputs.json), [reviewable source checkpoint](evidence/garage-first-entry-2026-11-14/task.patch).

The 18-file normalized checkpoint applies and reverses exactly in a private fixture, including task-start controls and documentation. Owned runtime/test/tool source hashes match the final receipt. Concurrent changes to Garage selection, newspaper/track UI, vehicle assets and generated identity were preserved.

Representative actual commands (every run's exact engine command and result is retained under the evidence `runs/` directory):

```powershell
python scripts/run_garage_first_entry.py final-before-gl-1 --before
python scripts/run_garage_first_entry.py final-after-gl-1
python scripts/run_garage_first_entry.py reflections-mobile --renderer mobile --script res://tests/test_garage_opening_reflections.gd
python scripts/run_garage_first_entry.py retained-preload-final --script res://tests/test_garage_preload.gd
python scripts/run_garage_first_entry.py fitted-challenger-final --vehicle=super_rally --fitted
python scripts/run_garage_first_entry.py shared-capture-mobile --renderer mobile --script res://tests/test_shared_graphics_preparation.gd
python scripts/run_garage_first_entry.py parse-final --headless --script res://tests/check_model_refinement_parse.gd
python -m py_compile scripts/run_garage_first_entry.py
```

The runner isolates App storage/network configuration, wraps unattended Godot through `run_no_crash_dialog.py`, and now stops only its owned process tree on script failure/timeout. Full test profiles and shader caches stay under disposable `build/`; concise receipts, task-start controls and relevant native captures are retained here. Standard repository retention cleanup is applied at closeout. No task staging/commit, physical-device query/test, export, backend operation/deployment, owner-save edit or owner-process restart was performed. Reload the client to use the source changes; owner and phone acceptance remain.

The prescribed cleaner reported 25.015 GiB remaining, zero eligible deletions and no failures; recent/protected output remains above the 20 GiB target. This task created no retention pin. The [cleanup receipt](evidence/garage-first-entry-2026-11-14/retention.json) is retained.

Native captures: [before](evidence/garage-first-entry-2026-11-14/before-live.png), [after](evidence/garage-first-entry-2026-11-14/after-live.png), [desktop Mobile first live view](evidence/garage-first-entry-2026-11-14/mobile-first-live.png), [reflections on](evidence/garage-first-entry-2026-11-14/reflections-on.png), [diagnostic reflections off](evidence/garage-first-entry-2026-11-14/reflections-off-diagnostic.png). Full-App captures were visually reviewed; no pixel-identical full-App claim is made.
