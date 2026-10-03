# Race pause drawer — 2026-10-01

Requirements: R01/V03/V04/G03/Q01; owner reference and follow-up requesting a monochrome, animation-free paused race.

2026-10-02 V03/Q01 distinct actions: `game/ui/race_pause_menu.gd` now uses the existing play triangle for Resume and horizontally mirrors the tangent-aligned arrow for clockwise Restart. Racing Rewind remains counter-clockwise. Actual command `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 CapturePause` passed all 17 checks. Refreshed desktop and compact evidence in `docs/evidence/pause-menu/`; desktop inspected. Both status documents updated. Owner visual acceptance remains; no Android export or physical-device test performed.

2026-10-02 V03/Q01: Restart now reuses the tangent-aligned `rewind.svg` arrow in `game/ui/race_pause_menu.gd`. Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 CapturePause` passed 17 checks, zero failures. Refreshed `docs/evidence/pause-menu/1280x720.png` and `960x540.png`; desktop screenshot inspected. No Android export or physical-device test performed; owner visual acceptance remains. Both status documents updated.

The hamburger is the single pause action in races and untimed creator practice. Practice retains its untimed label and Edit here action. Escape toggles the same drawer. Resume/close restore driving; Restart requests a fresh attempt; Quit returns through the existing exit flow. Settings and Help remain inside the paused overlay. Settings exposes session sound and saved steering method. Report track is visibly unavailable because no reporting service exists; graphics settings and reporting submission are not implemented by this slice.

The original vector icons and editable navy drawer follow the supplied composition, with cyan Resume and red Quit. No reference-image pixels ship. A viewport snapshot captured on pause is shown in monochrome above every gameplay canvas layer. This freezes all visible world/HUD/shader animation and leaves the drawer in colour. Simulation and controls remain paused through the existing game state. Dust, smoke, sand spray, grass, snow and water GPU particles now explicitly freeze their particle clocks and resume from the same point. A rewind shortcut cannot open an invisible overlay behind the drawer.

Changed files: game/ui/race_pause_menu.gd (new), game/ui/playground_hud.gd, game/ui/menu_icon.gd, game/core/game.gd, game/vehicle/sand_dust.gd, game/tests/test_pause_menu.gd (new), game/tests/test_editor_practice.gd, game/tests/test_bridge_hud.gd, scripts/dev.ps1, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md. Existing unrelated working-tree changes were retained.

Actual commands (PowerShell, repository root, pinned Godot 4.7.2):

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/race_pause_menu.gd`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CapturePause`: final 17 checks, zero failures. Checks frozen pixels over 20 rendered frames, monochrome sample, stopped simulation, dust pause/resume, settings remaining paused, resume input and rewind exclusion. Saves desktop and compact evidence.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestPractice`: 53 checks, zero failures; four ObjectDB instances reported at exit.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRewind`: 54 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestBridgeHUD`: final 141 checks, one failure: `road faces point up for correct bridge lighting`. All drawer checks pass. The bridge invariant remains intact; bridge geometry was not changed in this task.
- `git diff --check`: passed (line-ending normalization warnings only).

Initial verification found obsolete popup/practice-button test expectations and delayed dust-clock restoration; corrected and rerun as above.

Inspected screenshots: [1280×720](evidence/pause-menu/1280x720.png), [960×540](evidence/pause-menu/960x540.png). The countdown fixture deliberately demonstrates that higher-layer race cues also become monochrome and frozen.

Remaining acceptance: owner visual review, real touch/Android pause/resume, and snapshot readback latency/memory on phone. No Android export or physical-device test was performed; device attachment was not verified. Snapshot allocation is one viewport-sized texture per pause, replacing the prior capture. No canonical simulation, timing, checkpoint or replay rules changed. No commit combines the pre-existing unrelated edits with this slice.
