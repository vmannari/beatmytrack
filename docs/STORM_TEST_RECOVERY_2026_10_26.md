# Test-drive save recovery — 26 October 2026

The reported test-drive modal could not accept input because it belonged to the retained, disabled editor. The original dialog also offered no explicit exit after a failed save. Owned dialogs now process input independently, and failed creator-test saves offer **Retry saving** and **Return to editor / Return to drafts**. An incomplete recording offers **Restart** instead of an endless save retry.

Requirements: TSR01 working input and exit; TSR02 truthful failure causes and exact retry; TSR03 eligible-track and account/attempt fences; R01 retained behavior; Q01 native evidence and scoped checkpoint.

## Findings and behavior

The original Storm documents contained layout knots with no road parts or placed start line. They could be driven, but `TrackLibrary.mark_tested` correctly rejected a completion receipt. The recording had already been staged locally. The generic free-storage message hid that distinction. Separately corrected normal-road versions are documented in [STORM_ROAD_PARTS_2026_10_26.md](STORM_ROAD_PARTS_2026_10_26.md); those source/draft changes are excluded from this checkpoint.

Practice eligibility now uses the same placed-start-line and valid-road-route requirements as the receipt writer. Incomplete drafts remain driveable as untimed practice. No receipt or publication status is fabricated. Save recovery reports the actual lifecycle/storage cause, pauses the car and preserves the captured document, car, scope, witness and trajectory. A receipt-only retry reuses the staged proof and operation identity. Return retains the draft and any already staged proof. Escape/X dismisses the modal; a later pause-menu exit reopens the pending choices. Repeated completion cannot stack windows. Tab and Enter activate the focused Return action; touch/mouse and Escape are also checked. Account changes, new attempts and replaced documents fence stale callbacks.

The full App test confirms Return restores the same editor root, canvas, world and document. Normal race scoring, physics, controls, cameras, backend contracts and publication authority are unchanged by this work. New descriptive copy currently uses the English fallback.

## Files

- `game/core/app.gd`: active owned dialogs; pending-save context, exact retry, recovery and return.
- `game/core/game.gd`: valid authored-track eligibility at restart.
- `game/ui/practice_save_recovery.gd`: responsive two-action recovery dialog.
- `game/tests/test_practice_save_recovery.gd`: real input/ordered laps, injected receipt failure, exact proof, mouse/touch/keyboard, layout and stale-callback checks.
- `game/tests/test_practice_save_roundtrip.gd`: full App failure, retained-editor return and incomplete-proof restart.
- `game/tests/probe_practice_original_game.gd`: original-Game diagnostic control; original files load only in isolated process memory.
- `game/ui/garage_cached_thumbnail.gd`: one compatibility signature argument matching the concurrently changed parent; an unrelated parser error initially prevented loading App tests. No thumbnail behavior change.

## Actual validation

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. All tests use isolated APPDATA, drafts, records and cloud paths beneath `build/storm-test-recovery-2026-10-26`; no owner save writes or service requests.

| Check | Result |
| --- | --- |
| Recovery headless / Compatibility / desktop Mobile | 43 / 58 / 58 checks, zero failures |
| Full App failure/return/restart, Compatibility | 16 checks, zero failures |
| Existing App regression | 141 checks, zero failures |
| Existing notice input/focus/layout, Compatibility / desktop Mobile | 95 / 95 checks, zero failures |
| Existing local draft/publication journal | 31 checks, zero failures; 2,605 actual ticks, 436 proof samples |
| Full project parser | 1,259 scripts, zero failures |
| Original recovery control | 30 checks, six expected failures, including disabled input and absent exit |

The broader existing `test_editor_practice.gd` remains failing: Ellipse completes zero laps in 28,800 ticks with 27,678 contacts, then four assertions fail and a missing finish state causes an error. Loading the exact original Game reproduces the same values and failures. This test is not reported as passing and its assertions are unchanged. The focused tests use the existing verified oval fixture and genuine ordered input laps.

Initial failures are retained under the evidence `logs/` directory: incorrect headless layout/mouse event routing in the first test fixture; an original duplicate exclusive-window error; and the concurrent Garage override signature mismatch. Correcting the fixture routes mouse events through the embedded window's parent and supplies actual logical viewport dimensions. Native layout checks cover 1280×720, 960×540, 600×800 and 390×844 without reducing action-size or overlap assertions.

Commands used, with `$env:APPDATA` set to the isolated folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_practice_save_recovery.gd -CommandTimeoutSeconds 600
# Same test with -Graphical -RenderingMethod gl_compatibility, then mobile.
# Original control: -TestArgument '--original'.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_practice_save_roundtrip.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_app.gd -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_fault_dialog.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 600
# Mobile notice run also uses -TestArgument '--evidence=res://../docs/evidence/storm-test-recovery-2026-10-26/mobile/notices'.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_local_draft_publication.gd -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_editor_practice.gd -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/probe_practice_original_game.gd -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 600
```

Native [desktop](evidence/storm-test-recovery-2026-10-26/gl_compatibility/recovery.png) and [compact](evidence/storm-test-recovery-2026-10-26/mobile/recovery-390.png) captures show the actual paused Game and working recovery actions. [report.json](evidence/storm-test-recovery-2026-10-26/report.json) records evidence hashes and the scoped, reverse-checkable patch. Concurrent changes in shared App/Game files are excluded from the patch. No staging or commit.

Relaunch/rebuild is required to load the code. Owner acceptance of the original workflow and translated copy remains. No physical-device attachment check or device test, APK, authentication, purchase, live database mutation, deployment, merge or owner-process restart was performed.
