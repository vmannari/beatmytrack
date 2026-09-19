# Race start clearance — 2026-09-15

Owner request / requirements G01, V03, V05, R01, R07: start before the finish stripe and raise the countdown/GO text clear of the car.

## Changes

- `game/core/game.gd`: ordinary races and retries move the stored spawn backwards along the finish direction until its centre is at least 3 m before the stripe. Existing farther-back starts and editor practice placement are retained. Countdown and GO share a box raised 110 logical pixels.
- `game/race/race_rules.gd`: `standing-5-local-v2` separates PBs for the changed starting distance. Older records remain stored under their previous key. Five laps and canonical handling are unchanged.
- `game/tests/test_editor_practice.gd`: start clearance and announcement layout checks; actual countdown and GO captures alongside the existing practice/five-lap driving witness.
- Status/plan entries and this evidence document.

## Actual validation

All commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ...` and pinned Godot 4.7.2:

- `Import`: passed; missing Android build-tools reported.
- `CapturePractice`: 36 checks, zero failures; six untimed practice laps without collisions and a completed five-lap ordinary race. Countdown and GO captures visually inspected at 1280×720: car behind stripe, announcements above car.
- `TestRecords`: 53 checks, zero failures.
- Corrected `TestPractice`: 33 checks, zero failures; two ObjectDB instances reported at test exit.
- Initial `TestPractice` exposed a new assertion accidentally placed in the practice case; corrected to the normal-race case. Initial capture encountered uncached HUD classes from concurrent workspace changes; Import resolved them.

Evidence: [Countdown](evidence/race-start/countdown.png), [GO](evidence/race-start/go.png).

No device test or Android export performed. Phone readability and owner visual acceptance remain pending. Arbitrary creator-track start geometry has not been exhaustively tested; this adjustment preserves lateral spawn placement and heading. Existing unrelated workspace changes were retained.
