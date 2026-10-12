# Desert wind and dune sand, 2026-10-10

Current SND44 uses three sections from the owner's supplied wind recording,
shuffled across races/retries with fresh phase/gust variation. Supplemental sand
gain is reduced under its quieter lulls. [Current implementation and actual
verification](DESERT_OWNER_WIND.md). The SND42 details below record the initial
synthetic-wind implementation and its historical measurements.

SND42 implements the owner's next biome-audio slice: desert wind and sand dunes.
G01/R01 preserve canonical driving; Q01 covers actual verification and provenance.

`DesertAmbience` supplies two race-owned Vehicle-bus voices only in Desert.
Open-air wind is the main bed; fine dry wind-blown sand rises beneath stronger
gusts. Both play at rest and during the starting countdown. The existing
wheel-contact sand/rolling/debris audio continues to follow driving independently.

Every race/Retry picks fresh37-second wind and29-second sand loop offsets and
small mix variations. Gusts alternate smoothly between high0.55–1.0 and
calm0.0–0.2 strength, taking3.5–7 seconds per transition with2–8-second holds.
The opening fade lasts2 seconds. Wind gain is bounded at0.297 and sand at0.13125;
the sand responds more strongly to high gusts. A local RNG and presentation
clock are independent of simulation. Long frames cannot fast-forward through
missed gusts. No wind forces, traction, dust behavior or dune geometry change.

Pause/rewind and OS background suspension freeze both voices and gust timing.
Finish fades them out within0.6 seconds and stops scheduling. Retry restarts the
fade and variation. Biome changes stop both immediately; exit frees their
voices. Existing sound settings/mute cover both. No extra UI or settings,
runtime generation/download/service or dependency is introduced.

The two assets are original offline sound design, not field recordings.
`scripts/build_desert_ambience.py` renders filtered noise into low/open air bands
and quieter fine sand with overlapping5–25ms damped grains. Periodic spectra and
slow harmonic envelopes provide long evolving textures, rotated to quiet seams
without a fade-to-silence loop join. The runtime only plays pre-rendered mono
44.1kHz16-bit PCM using the existing cyclic interpolation guard. Source recipe,
fixed seeds, RMS/peak/seam measurements and derivative hashes are in
`desert_ambience_manifest.json`. NumPy is an existing offline build tool.
No third-party recording, paid asset or external AI service is used.

The wind asset is3,263,444bytes/37seconds, and dune sand2,557,844bytes/29seconds:
5,821,288bytes (~5.55MiB) added. No existing vehicle or Grass/Night audio asset
is edited. Two active ambience voices are added in Desert, separate from the
existing bounded vehicle mixer.

Changed files:

- `game/track/desert_ambience.gd` and `.uid`: two voices, randomized gusts and lifecycle.
- `game/core/game.gd`: seven added lines for setup, presentation and Retry.
- `game/assets/audio/ambience/desert_wind.wav`, `desert_dune_sand.wav`, their `.wav.import` files, `desert_ambience_manifest.json`, and `NOTICE.txt`.
- `scripts/build_desert_ambience.py`, `scripts/review_desert_ambience.py`.
- `game/tests/test_desert_ambience.gd` and `.uid`.
- `licenses/ASSETS.md`, this document, `docs/DESERT_CONTINUOUS_AUDIO.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands:

```powershell
python scripts/build_desert_ambience.py
# Repeated: both derivative SHA256 hashes reproduce exactly.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_nature.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_continuous_desert_audio.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python scripts/review_desert_ambience.py
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
```

Pinned Godot4.7.2 import/headless97/native109/Grass107/vehicle-desert28/App99 checks
pass. Six90-second schedules verify varying phases/gusts, bounded levels, smooth
transitions, stationary ambience, lifecycle, voice reuse, actual Desert race
ownership/Retry/exit and an unchanged canonical snapshot. Fast schedule checks
disable decoder output; real-time native capture enables it. Both actual loop
crossings pass, including the interpolation guards.

Native wind and sand samples are8 seconds each, at−36.945/−48.707dBFS RMS:
sand is11.761dB quieter over these complete samples. Two20-second combined mixes
vary phases, mix and gust timing and have peaks0.0821/0.0865 with no clipped
samples. Every settled50ms window remains audible, so no cyclic silence gap was
observed. Both masters have zero quantized endpoint step and seam energy ratios
1.018/1.016 against adjacent50ms regions. Paused/muted/finished~0.4-second native
samples are exactly silent. These are isolated ambience recordings; full driving
balance and subjective listening remain acceptance checks.

Evidence: [desert mix A](evidence/desert-ambience-2026-10-10/mixed0.wav),
[desert mix B](evidence/desert-ambience-2026-10-10/mixed1.wav),
[measured report](evidence/desert-ambience-2026-10-10/review.json), isolated
wind/sand and silence samples, event JSONs, focused logs, `task-only.patch` and
`checkpoint.json`. The isolated Git checkpoint leaves the main index/branch
untouched and excludes concurrent status/ledger additions.

Source research considered publicly listed desert samples; none is downloaded,
included or attributed as the source of these original assets. No test failure
occurred in the focused implementation/native checks. An early inspection used
the wrong older document filename and was corrected before implementation; an
unapplied documentation patch was corrected against the actual heading.

One authorized OPD2403 tablet is attached; no phone is attached. No Android
export/install, device listening/performance, full Validate, physics/backend
change or deployment was performed. Remaining acceptance: restart/rebuild and
listen during a Desert race across several retries, judge wind/sand balance
against the engine, and verify pause/rewind/finish on the actual Android device.
UI is unchanged; screenshots are unnecessary.
