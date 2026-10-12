# Free Race bottom actions, 2026-10-09

Requirements: RR06/V03/V05/Q01. The owner reports clipped bottom buttons. Fixed section minima required 604 logical pixels below the menu header, exceeding available height. `game/ui/track_browser.gd` reduces the flexible hero minimum from 200 to 160; charts remain 180, carousel 140 and actions 60 pixels. Taller windows retain the expanding preview.

`game/tests/test_unified_histograms.gd` now reserves 112 pixels for the header and 16 for bottom padding, with 18-pixel side margins, and checks the full action row remains inside the browser at three window sizes. DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md record the outcome.

Actual command: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical -CommandTimeoutSeconds 90`, with isolated APPDATA `build/free-race-buttons-user` and BMT_RESULTS_EVIDENCE `docs/evidence/free-race-buttons-2026-10-09`. Pinned Godot 4.7.2 stable ed1daf0bf: **144 checks, zero failures** at 1280x720, 960x540 and 1600x720. Initial restricted run failed accessing the Windows certificate store; permitted rerun succeeded.

[Log](evidence/free-race-buttons-2026-10-09/check-permitted.log), [inspected capture](evidence/free-race-buttons-2026-10-09/discovery-1280x720.png), [task-only review checkpoint](evidence/free-race-buttons-2026-10-09/scoped-change.patch). Capture uses the existing histogram fixture without the live menu header/backdrop or populated carousel; the equivalent header space is reserved. No server/player records written.

No phone attachment check or physical-device test performed; no Android export/install, full Validate, backend or production deployment. Remaining acceptance: owner review of the populated live menu and physical-device layout.
