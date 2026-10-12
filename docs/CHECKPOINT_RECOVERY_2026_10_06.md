# Checkpoint warning after returning

Requirements: T01–T04/Q01; ordered road-gate override (2026-09-22). The owner reports upcoming checkpoints being marked missed after returning to an earlier missed checkpoint.

The warning projection searched only three segments around the collision resolver's route hint. A shortcut return can cross the required gate while that hint still refers to a distant part of the route. Acceptance correctly advances to the next gate, but the subsequent projection immediately flags that upcoming gate as missed. This resembles retained maximum progress, although `last_progress` itself was recalculated every tick.

`game/race/track_session.gd` now bakes a route segment hint for each gate. Notice/display projection compares the simulation hint corridor with the last accepted gate corridor and chooses the physically closer projection. Simulation hints win near-equal distance ties to preserve branch continuity at overlapping roads. The search remains bounded to at most six segments per call. Swept acceptance, gate order, layers, finish logic, rules v18 and vehicle physics are unchanged. No player files, backend deployments or record migrations were performed.

`game/tests/test_checkpoint_notices.gd` adds 252 assertions covering 84 recovery gates across Silmukka, Dust cloud and Over and under: ordinary return from three gates ahead, return with a distant route hint and the following tick before the hint catches up. The initial distant-hint regression failed all 84 cases before the fix (449 checks/84 failures). Final suite: 533 checks/0 failures. These deliberately seed stale hints; they establish the warning defect but do not constitute a recording of the owner's particular race.

`game/tests/capture_checkpoints.gd` adds the opt-in `return-recovery` desktop diagnostic. It sweeps outside a gate to generate the actual warning, seeds progress/hint three gates ahead, returns through the required gate, and verifies both HUD and marker clear. Capture: 22 checks/0 failures. Both screenshots were inspected:

- [Missed gate](evidence/checkpoint-recovery-2026-10-06/missed.png)
- [Recovered, upcoming gate stays clear](evidence/checkpoint-recovery-2026-10-06/recovered.png)

Actual commands used the pinned Godot 4.7.2 via the build entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_checkpoint_notices.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_checkpoint_rules.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_checkpoint_bridge_layers.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_exit_checkpoints.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rewind.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCheckpoints -Screen return-recovery
git diff --check -- game/race/track_session.gd game/tests/test_checkpoint_notices.gd game/tests/capture_checkpoints.gd
```

Final results: notices 533, ordered rules 266, bridge layers 259 (including an actual five-lap compact simulation), bridge exits 2527 (all five vehicles), rewind 57 and graphical capture 22; all zero failures. Gate benchmark reported 4.44 microseconds/tick on this desktop. Scoped whitespace check exits 0; existing CRLF normalization warnings remain. No physics merge or full-project Validate was performed.

Initial direct script invocation was blocked by the PowerShell execution policy. Process-scoped Bypass corrected that. The first sandbox engine run failed to write its ordinary user log; subsequent permitted engine runs succeeded. Logs and the source-only Git diff checkpoint are retained in the evidence directory, preserving unrelated in-progress changes.

Remaining acceptance: replay the owner's exact missed-checkpoint/return sequence on the affected track and a current Android build. Phone attachment was not checked; no physical-device test, Android export/install or backend deployment was performed. The installed build will retain old behavior until rebuilt.
