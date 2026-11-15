# Garage car selection feedback — 2026-11-14

GSF01: A Garage card activation updates its selected border, caption and heading immediately. The UI draws that selection before synchronous model construction begins. Previously the card callback built the next car before refreshing its highlight.

GSF02: Pending requests retain only the latest choice. Returning to the displayed car cancels the pending build. Select, workshop navigation and Test drive finish the latest request before using it. Direct `preview_car()` callers retain their synchronous behavior.

GSF03: Hiding, freeing or refreshing the page cancels deferred work. The displayed car, paint and condition stay together until replacement. Existing camera/zoom, preview versus confirmation semantics and the 0.26s disappear/0.38s appear transition remain. The owner's optional slower transition was unnecessary for this fix: feedback no longer waits for that transition or model construction.

Changed runtime source: `game/ui/garage_page.gd`. Added regression: `game/tests/test_garage_selection_feedback.gd`. Concurrent newspaper-entry changes in the same runtime source were preserved. This task changes no car geometry, handling or prepared model data.

## Verification

Pinned engine: `C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe`, version `4.7.2.stable.official.ed1daf0bf`. Every process used an isolated disposable profile below `build/garage-selection-2026-11-14/`, an empty `BMT_API_URL`/`BMT_DEV_AUTH_KEY` and Dummy audio for direct runs.

| Check | Result |
| --- | --- |
| New input/lifecycle regression, headless | 20 checks, 0 failures |
| New regression, desktop Compatibility | 23 checks, 0 failures; dispatch 1.534 ms |
| New regression, desktop Vulkan Mobile | 23 checks, 0 failures; dispatch 1.840 ms |
| Original blocking callback control, Compatibility | 23 checks, 8 expected failures; dispatch 415.027 ms |
| Existing `test_garage_switch_pick.gd` | 25 checks, 0 failures |
| Existing actual-App `test_garage_simple_models.gd` | 239 checks, 0 failures |
| Production parser `check_model_refinement_parse.gd` | 568 scripts, 0 failures |

The new regression dispatches real mouse/touch input, adds 180 ms deliberately to the first model build, and reads rendered pixels at construction entry. Both renderers show the new selected border before construction. The blocking control overrides only the card callback to call synchronous `preview_car()`, reproducing the original scheduling without swapping live production sources. Its captured border still belongs to the old car. These are desktop dispatch samples with an artificial delay, not cold-load, frame-rate or phone measurements.

The first headless attempt exposed fixture issues (unfinished initial menu motion, obsolete Pickup index assumptions) and a missing headless substitute for the draw signal. The corrected fixture uses the current Kart slot and finishes initial menu motion; the runtime waits one process frame under headless. The first disposable original-source control could not compile because helper properties require the actual `GaragePage` type; it was replaced with the callback override above. No existing assertion was weakened.

Actual commands, with the per-run environment/profile prefix described above:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_selection_feedback.gd -CommandTimeoutSeconds 180
& $godot --headless --path game --audio-driver Dummy --script res://tests/test_garage_selection_feedback.gd
& $godot --path game --audio-driver Dummy --position 10000,10000 --rendering-method gl_compatibility --script res://tests/test_garage_selection_feedback.gd -- --evidence-root=res://../docs/evidence/garage-selection-2026-11-14/gl_compatibility
& $godot --path game --audio-driver Dummy --position 10000,10000 --rendering-method mobile --script res://tests/test_garage_selection_feedback.gd -- --evidence-root=res://../docs/evidence/garage-selection-2026-11-14/mobile
& $godot --path game --audio-driver Dummy --position 10000,10000 --rendering-method gl_compatibility --script res://tests/_garage_selection_baseline.gd -- --evidence-root=res://../docs/evidence/garage-selection-2026-11-14/baseline
& $godot --headless --path game --audio-driver Dummy --script res://tests/test_garage_switch_pick.gd
& $godot --headless --path game --audio-driver Dummy --script res://tests/test_garage_simple_models.gd -- --evidence-root=res://../docs/evidence/garage-selection-2026-11-14/simple-models
& $godot --headless --path game --audio-driver Dummy --script res://tests/check_model_refinement_parse.gd
python build/garage-selection-2026-11-14/checkpoint.py
git diff --check -- game/ui/garage_page.gd game/tests/test_garage_selection_feedback.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The wrapper's initial run regenerated client metadata; generated identities are excluded from the task checkpoint. Later direct checks use the same verified pinned engine. The disposable baseline scripts were removed after verification.

Evidence: [results and source hashes](evidence/garage-selection-2026-11-14/validation.json), [task-only source checkpoint](evidence/garage-selection-2026-11-14/source.patch), [Compatibility highlight before construction](evidence/garage-selection-2026-11-14/gl_compatibility/highlight-before-construction.png), [Mobile highlight before construction](evidence/garage-selection-2026-11-14/mobile/highlight-before-construction.png), [blocking control](evidence/garage-selection-2026-11-14/baseline/highlight-before-construction.png). The source checkpoint applies and reverses exactly in a disposable file-only checkout, preserving concurrent changes; the main Git index was not staged or committed.

Model construction is still synchronous after the first feedback draw, so a particularly expensive build can pause subsequent animation. Immediate confirmation can also require synchronous construction. No additional fixed animation delay or model-loading speedup is claimed. Reload and owner feel/appearance acceptance remain; no physical-device query/test, export, backend request/deployment or owner-process/save change was performed. Standard build retention ran; the existing recent/protected build output can exceed the 20 GiB target.
