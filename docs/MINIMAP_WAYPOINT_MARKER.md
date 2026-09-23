# Minimap waypoint marker removal

2026-09-22 owner follow-up. Requirements **V03 / V05 / R01**.

The race minimap no longer draws or stores the next/missed checkpoint marker. It continues to show only placed-road geometry and the blue player marker. Missing a required road gate still presents the yellow marker in the world and the persistent `CHECKPOINT ... MISSED - RETURN` HUD notice, so the recovery rule and race timing are unchanged.

Changed files: `game/ui/hud_road_map.gd`, `game/core/game.gd`, `game/ui/checkpoint_marker.gd`, `game/tests/capture_checkpoints.gd`, this report, the status/phase-plan entries and the refreshed checkpoint capture.

Actual commands and outcomes:

- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 CaptureCheckpoints`: **7 checks, zero failures**. The refreshed 1280x720 capture was inspected and contains no yellow waypoint dot on the minimap.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 TestBridgeHUD`: **153 checks, zero failures**.

[Desktop evidence](evidence/checkpoint-forgiveness-2026-09-22/checkpoint-missed.png).

No Android export or phone/device test was performed. Remaining acceptance is visual confirmation on the target phone. No gameplay, checkpoint-validation or physics behavior changed.
