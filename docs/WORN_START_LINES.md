# Worn start/finish paint — 2026-10-05

Requirements V03/V04/V05/Q01. The owner's “starting light” request was interpreted as the start/finish checker line, because Desert and Winter already have the requested worn road marking. Grass, Night and Storm now share that abrasion shader, deterministic missing pigment and irregular edges. Muted grey/off-white asphalt pigment preserves the checker pattern. Desert and Winter retain their existing palettes. Countdown lights, timing, gates, collision and gameplay cameras are unchanged.

Changed files: `game/track/native_track_visual.gd` (track-kit-112), `game/tests/test_storm.gd` (updates the superseded glossy paint expectation), `game/tests/capture_worn_start_lines.gd`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and this document. No new assets or dependencies; existing project-generated surface factors are reused.

Actual commands, run with pinned Godot 4.7.2 through the entry point:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestStorm`: 91 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestStartLine`: 27 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_worn_start_lines.gd -Graphical`: final exit 0; five biome screenshots. Grass, Night and Storm inspected. Night fixture includes an ordinary track lamp to show the marking under actual biome illumination.

The first sandbox capture could not write the engine user log; desktop execution with local user-data access succeeded. The first fixture omitted document JSON normalization, produced a null compiled track and exited 1; corrected before final captures. These attempts are not passing results.

Evidence and scoped review checkpoint: `docs/evidence/worn-start-lines-2026-10-05/` includes screenshots, the pre-change visual source and `scoped-change.patch`. Existing concurrent visual/backend changes are preserved; no mixed Git commit was made.

Remaining acceptance: owner visual approval, Night readability on authored tracks with their own lighting, phone viewing and performance. No phone attachment check, Android export or device test was performed. Detail camera in the capture fixture is for inspection only.
