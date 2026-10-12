# Owner-supplied Winter blizzard — 2026-10-11

SND47 replaces the rejected SND46 synthetic wind with the owner's supplied
`dragon-studio-blizzard-wind-463217.mp3`. G01/R01 preserve canonical driving;
Q01 covers source fidelity, actual tests and provenance.

Active Winter wind now derives entirely from that recording. Regions0.3–17.3s
and2.0–17.0s produce15.5/13.5-second loops after1.5-second correlation-aware
power joins. Original recorded pitch/tone is preserved; smooth0.75-second RMS
leveling with0.5-second gain smoothing lifts quieter passages, followed by DC/
level matching and zero-step energy-balanced seam rotation. No EQ, synthesized
wind, extra whistles or other layers are added. The earlier generated loops and
their recipe remain only in export-excluded checkpoint history.

The existing Winter runtime is unchanged: one Vehicle-bus voice, alternating
variants without immediate repeats, fresh playback offsets/level/gust timing
per race and Retry, continuous settled gain floor0.36, maximum0.616,1.5-second
opening and0.6-second finish fades. Pause/rewind/background/mute freeze or silence
sound; biome change stops it; exit frees the voice. Other biome/vehicle/snow/ice
audio, physics, camera, UI, five laps and backend remain intact.

The original MP3 is566,784bytes/17.712seconds; SHA256
`65f21e931e6ee233972d765fc7f8323c4319bf3067d2e5724577119ea3c171cc`.
It was copied read-only into export-excluded build storage and verified unchanged
in Downloads. Pinned Godot4.7.2 decodes781,100mono frames at44.1kHz; decoded
SHA2565aad5bd9… is pinned in `winter_wind_manifest.json`, alongside the original,
derivative and per-frame loudness-profile hashes. Filename attribution is Dragon
Studio; original licence metadata was not provided, and no CC0 licence inferred.
Local use/edit is the owner's explicit request. The shipping notice and asset
ledger retain that provenance.

The two new WAVs are1,367,144/1,190,744bytes, totaling2,557,888bytes (~2.44MiB),
3,087,000bytes smaller than SND46. Full decode/rebuild repeats both hashes exactly:
a5e59aae…/007cb0b9…. No extra runtime voice, download/service or dependency.

Changed files:

- `scripts/build_winter_wind.py`: pinned recording decode, source excerpts, joins and leveling replace the original synthesized recipe.
- `game/assets/audio/ambience/winter_gale_a.wav`, `winter_gale_b.wav`, `winter_wind_manifest.json`, `NOTICE.txt`.
- `scripts/review_winter_wind.py`: verifies recorded source shape through documented level gain instead of the rejected synthetic-brightness target.
- `game/tests/test_winter_wind.gd`: exact15.5/13.5-second source fixtures and new evidence destination.
- `docs/WINTER_WIND.md`, this document, `licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands:

```powershell
Copy-Item -LiteralPath 'C:/Users/ville/Downloads/dragon-studio-blizzard-wind-463217.mp3' -Destination build/winter_owner_wind/sources/blizzard.mp3
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/decode_storm_rain_source.gd -TestArgument @('--source-path=res://../build/winter_owner_wind/sources/blizzard')"
python scripts/build_winter_wind.py
python scripts/build_winter_wind.py --decode
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_wind.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python scripts/review_winter_wind.py
Get-FileHash -LiteralPath 'C:/Users/ville/Downloads/dragon-studio-blizzard-wind-463217.mp3' -Algorithm SHA256
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
```

Import/headless87/native100/App99/final PCM review pass. Six60-second schedules
cover variant/phase/gust variation and the continuous floor; actual Winter race
setup/Retry/exit and canonical snapshot equality remain covered. Both native
loops cross their boundaries. Pause/mute/finish samples are exactly silent.
The old30/34-second fixtures and >900Hz synthetic-centroid target are explicitly
superseded by the owner's new source; all continuity, balance, silence and
canonical assertions remain. Source shape correlation after the documented
loudness envelope is>0.99999999, with errors<0.00004 (16-bit PCM quantization).

Both masters have zero endpoint steps, seam-energy ratios0.932/0.932 and actual
centroids408/412Hz, retaining the provided lower roar rather than the rejected
brighter synthesized character. Two20-second race samples use different variants,
phases and gusts; minimum settled500ms RMS0.02627/0.02492, peaks0.1450/0.1524,
unclipped. A controlled8-second Compact mixer at25m/s (90km/h) peaks0.2370,
unclipped. It is a fixed-speed mixer diagnostic, not a completed race, subjective
listening or mobile-performance claim.

Evidence: [recorded blizzard race A](evidence/winter-owner-wind-2026-10-11/race0.wav),
[race B](evidence/winter-owner-wind-2026-10-11/race1.wav),
[with engine](evidence/winter-owner-wind-2026-10-11/driving.wav),
[measured report](evidence/winter-owner-wind-2026-10-11/review.json), isolated gale/
silence WAVs, event JSONs, focused logs and task-only Git checkpoint/patch in the
same evidence directory. Main index/branch and concurrent work are untouched.

No focused test failure occurred. An initial unapplied file-replacement patch
used duplicate operations for one path; it was corrected to a single update
before rebuilding. No old synthetic audio is used as fallback or mixed in.

DN2103 phone attached. No phone listening, Android export/install, performance,
full Validate, backend work or deployment performed. Remaining acceptance:
restart/rebuild, listen to the previews and several Winter retries on the actual
phone, judge source character/engine balance and confirm pause/rewind/finish.
UI unchanged; screenshots are unnecessary.
