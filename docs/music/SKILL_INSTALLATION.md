# Music skill installation review ? 2026-09-27

Scope: owner-authorized skill corrections and repository installation; supports MUS01/MUS03/MUS06/MUS09/MUS10 tooling only. No soundtrack or runtime changes.

Changed: `.agents/skills/bmt-adaptive-music/`, `docs/music/STATE.md`; corrected package and installers retained under `temp/music-skill/fixed-v2/` and `beat_my_track_music_skill_v2_fixed.zip`. Original ZIP preserved. Python bytecode omitted.

Installers refuse existing targets and preserve existing state. Review helper requires FFmpeg, rejects existing output folders, measures LUFS/true peak, applies a safe common target, exports float WAV without overwrite, remeasures outputs, and verifies source hashes. State initialization reconciles historical approvals. Windows README commands use single lines.

Actual commands/checks:
- `python -B -S temp/music-skill/fixed-v2/bmt-adaptive-music/scripts/validate_skill.py temp/music-skill/fixed-v2/bmt-adaptive-music`: PASS.
- `python -B -S -m unittest discover -s temp/music-skill/fixed-v2/bmt-adaptive-music/tests -v`: 19 tests PASS, including seven helper behavior tests with mocked FFmpeg.
- Temporary-repository PowerShell installer test: fresh install PASS; second install refuses; existing STATE and local edits preserved.
- `powershell -NoProfile -ExecutionPolicy Bypass -File temp/music-skill/fixed-v2/install_skill.ps1 -RepoRoot "C:\Codes\Godot\Beat my track"`: installed successfully.

Limitations: FFmpeg unavailable on Windows PATH and current WSL PATH; no real decoding/rendering or listening performed. Tests exercise gain calculations and subprocess handling with mocks. Bash installer runtime test remains pending. No UI changes; screenshots not applicable. No Godot, Android, or device test performed. Remaining acceptance: actual FFmpeg export/peak verification and subsequent musical listening approval.
