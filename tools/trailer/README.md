# Native game trailer

Captures the current game into a 40-second, 1920×1080, 30 fps landscape review cut.
Uses the pinned Godot build, actual race simulation, App editor, Garage models,
and ChallengeCreate. It does not change runtime code or submit service requests.

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/trailer/capture.ps1 -Mode gameplay
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/trailer/capture.ps1 -Mode editor
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/trailer/capture.ps1 -Mode garage
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/trailer/capture.ps1 -Mode challenge
```

The launcher redirects APPDATA/LOCALAPPDATA to the workspace, supplies disposable
App records/library/cloud paths, disables the API URL, and uses Dummy audio.
The game receives normal RouteDriver inputs at its unchanged 120 Hz tick rate.
Every captured frame follows four ticks. The gameplay HUD is hidden; the normal
overhead follow camera remains. Garage is a separate native menu camera.

After the four captures, assemble with the existing local FFmpeg:

```powershell
wsl.exe -e python3 '/mnt/c/Codes/Godot/Beat my track/tools/trailer/assemble.py' --ffmpeg /home/ville/.local/share/bmt-music-tools/ffmpeg
```

Alternatively run `python tools/trailer/assemble.py --ffmpeg <native-ffmpeg>`.
The assembler requires Python 3.11+ and no third-party Python packages.
Outputs are in `build/trailer-2026-10-24/deliverables/`: MP4, local HTML player,
poster, contact sheet and provenance/validation JSON. Intermediate JPEGs and
encoder logs stay in the ignored build directory. Assembly uses hard links to
avoid duplicating frame storage. An existing timeline must refer to the same
raw frames; use a fresh output directory if changing the shot order.

The five-biome sequence uses one default creator circuit with the compact's
real cosmetic variants. The editor illustrates constructing a separate modular
closed circuit. The challenge shot selects formats locally; no challenge is
submitted, and no results or opponent data are fabricated. Music is the existing
original `score_v1/daybreak_current.ogg`, with CC0 source-instrument provenance
in that bank's NOTICE and manifest. This temporary music choice needs owner
creative review. The first cut uses music only.

Editorial changes consist of captions, cuts, opening/closing fades, a small
exposure lift on the dark Night shot, and music normalization/fades. There is no
generative footage, external media upload, APK, device test or deployment.
