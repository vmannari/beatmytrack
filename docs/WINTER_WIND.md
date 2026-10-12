# Harsh Winter wind — 2026-10-11

Current SND47 replaces the rejected synthesized wind with the owner's supplied
Dragon Studio blizzard recording. [Current recorded-source implementation,
previews and verification](WINTER_OWNER_WIND.md). The SND46 details below describe
the earlier synthesized candidate and its historical tests.

SND46 implements the owner's request for harsh winter-wind ambience. G01/R01
preserve canonical driving; Q01 covers actual tests, audio evidence and provenance.

Winter now has a race-owned `WinterWind` voice: a low gale roar, broad cutting
air and noisy whistling resonances. Two original30/34-second loops offer a
deeper and a brighter variation. Race/Retry changes the loop without an immediate
repeat, randomizes its starting point and level, and generates fresh smooth
gusts. After the1.5-second opening fade a steady gain floor0.36 remains between
gusts; gain is bounded at0.616. Gust transitions last2.5–5 seconds with variable
holds. Sound plays during countdown, at rest and while driving.

Pause/rewind and OS background suspend playback and freeze timing. Finish fades
out within0.6 seconds, biome changes stop the voice immediately, Retry resets
the fade/variation and exit frees the voice. Existing sound volume/mute includes
Winter wind. One playback voice, two cached PCM loops and a local presentation
RNG; no runtime synthesis/download/service, extra dependencies, physics forces,
UI labels, camera or driving-contract changes. Snow presentation and existing
Winter vehicle/ice audio remain intact. Other biome audio is unchanged.

The assets are original offline sound design, not field recordings or music.
`scripts/build_winter_wind.py` renders fixed-seed filtered noise into low roar,
cutting air and whistling bands with bounded slow periodic envelopes. The
periodic loops are level matched at−23dBFS RMS and rotated to exactly matching
PCM endpoints whose local energy matches neighboring regions; no fade-to-silence
join. Existing `PcmAudioLoop` supplies cyclic interpolation guards. Source
recipe/seeds/derivative hashes are in `winter_wind_manifest.json` and the shipping
notice/asset ledger. NumPy is an existing offline build tool only. No external
recording, paid asset or AI service is included.

WAVs total5,644,888bytes (~5.38MiB):2,646,044/2,998,844bytes, mono44.1kHz16-bit
PCM. Repeated generation reproduces SHA256a9760989…/e4884f27… exactly. One active
Winter voice is added; no mobile-memory/performance claim is made.

Changed files:

- `game/track/winter_wind.gd` and `.uid`: gale voice, variant/phase/gust variation and lifecycle.
- `game/core/game.gd`: seven added setup/presentation/Retry lines.
- `game/assets/audio/ambience/winter_gale_a.wav`, `winter_gale_b.wav`, their `.wav.import` files, `winter_wind_manifest.json`, `NOTICE.txt`.
- `scripts/build_winter_wind.py`, `scripts/review_winter_wind.py`.
- `game/tests/test_winter_wind.gd` and `.uid`.
- This document, `licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands with pinned Godot4.7.2:

```powershell
python scripts/build_winter_wind.py
# Repeated: identical asset hashes.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_wind.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python scripts/review_winter_wind.py
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
```

Import/headless87/native100/Desert111/App99 and PCM review pass. Six60-second
schedules cover variants/no-repeat/phase/gust variation, continuous bounded
levels, smooth gain changes, pause/background/mute/finish/biome/Retry/exit,
actual Winter-race setup and unchanged canonical snapshot. Both actual native
loop crossings pass. No assertion or invariant was weakened; no focused test
failure occurred.

Two20-second race samples have different variants/phases/gust timing and peaks
0.1688/0.1614 with no clipping; minimum settled500ms RMS is0.02621/0.02739.
Isolated six-second gale samples also stay continuous across their loop joins.
The masters have zero PCM endpoint steps, join energy ratios0.995/0.995 and
spectral centroids1,953/2,316Hz, documenting the intended brighter air character.
Pause/mute/finish~0.4-second recordings are exactly silent. A controlled8-second
Compact engine/vehicle mix at25m/s (90km/h) peaks0.2479 without clipping. It is a
fixed-speed mixer diagnostic, not a completed race or subjective listening claim.

Evidence: [Winter wind preview](evidence/winter-wind-2026-10-11/race0.wav),
[second race](evidence/winter-wind-2026-10-11/race1.wav),
[with engine](evidence/winter-wind-2026-10-11/driving.wav),
[measured report](evidence/winter-wind-2026-10-11/review.json), isolated gale/silence
WAVs, event JSONs, focused logs and task-only Git checkpoint/patch. Main index/
branch and concurrent work are untouched by the checkpoint.

DN2103 phone attached. No phone listening, Android export/install, device
performance, full Validate, backend work or deployment performed. Remaining
acceptance: restart/rebuild, listen to a Winter race across several retries on
the actual phone, and judge harshness/balance against the engine. Confirm pause/
rewind/finish acoustically. No visible UI change; screenshots are unnecessary.
