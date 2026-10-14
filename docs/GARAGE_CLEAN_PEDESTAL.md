# Clean car pedestal, 2026-10-13

Requirements GP01 remove the long lines, GC26 retain common platform geometry, V06/G01/Q01 preserve garage behaviour and provide actual evidence. Removed the two long inset bars at x=-0.92/+0.92 in game/ui/garage_environment.gd. The shared constructor updates main showrooms and actual 3D carousel previews for all five cars. Rim, 24 short perimeter markings, pedestal dimensions, satin material and live car reflection remain intact. No camera, car, canonical gameplay or cosmetic-save changes.

Actual command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_final_polish.gd -Graphical -TestArgument --evidence-root=res://../docs/evidence/garage-clean-pedestal-2026-10-13/layout
```

Pinned Godot4.7.2 Compatibility: GARAGE_FINAL_POLISH 38 checks, zero failures; all five main/card pedestal mesh buffers remain identical, retained camera/Reset framing, roof cutaway and shelf clearance pass. Eight actual screenshots saved; compact screenshot inspected and confirms no long lines with reflection retained. Existing test unchanged, no new tests for this small decorative removal. Log copied from build/logs/TestScript-22516.

Changed files: game/ui/garage_environment.gd, DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md and this report. [Screenshot](evidence/garage-clean-pedestal-2026-10-13/layout/fixed-platform-compact.png). Isolated task-only Git checkpoint: build/garage_clean_pedestal/checkpoint-repo; patch and checkpoint metadata in evidence directory. Main index/HEAD and unrelated workspace changes preserved.

No device interaction, APK export/install, Mobile rerun, full regression, physics merge or backend deployment performed for this edit. Phone visual acceptance remains outstanding. Physical connection was not queried this turn.
