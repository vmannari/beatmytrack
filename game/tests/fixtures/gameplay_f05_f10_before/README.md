# Gameplay F05–F10 baseline fixtures

`rewind_history.gd.txt` and `night_fire_volume.gdshader.txt` are exact copies from the workspace before this task's changes. Their SHA-256 values are recorded in `docs/evidence/gameplay-f05-f10-2026-10-23/before.json`. They are project-owned code, loaded only by the focused regression/profile scripts; `.txt` prevents global class registration. Preserve them as the original A/B controls.

Original texture mip chains are retained as `.ctex` evidence outside the export root. The fixture does not change physics or golden timing data.
