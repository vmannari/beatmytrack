# Owner-reference desert wind, 2026-10-10

SND45 (2026-10-11) raises the steady wind and levels quiet passages to keep
background sound present between gusts. The original source, variant selection
and pitch remain; loudness dynamics and wind masters change. [Current wind
presence, native engine mixes and actual tests](DESERT_WIND_PRESENCE.md).
The SND44 figures below describe the earlier quieter candidate.

SND44 refines SND42 at the owner's request: wind closer to the supplied
`tanweraman-desert-wind-1-350398.mp3`, varying between races. G01/R01 preserve
canonical driving; Q01 covers actual tests, source fidelity and provenance.

Active wind now derives directly from the supplied recording. Three overlapping
regions (0.6–14.6s,7.4–23.4s,13.6–27.6s) produce12/14/12-second loops through
two-second correlation-aware power joins. Original pitch and tone are retained;
editing is mono decode, DC removal, level matching and quiet seam rotation.
No EQ, synthetic wind or extra wind layers. Wind levels/slow gust behavior and
two-second opening/0.6-second finish fade retain the existing presentation.

Each race/Retry draws a section from a shuffled bag, using all three before
recycling and preventing immediate repeats at bag boundaries. Each section also
gets a fresh starting point, gain variation and gust timing. Prepared PCM loops
are cached once; one wind voice plays the selected section. Together with sand,
the Desert ambience still has two voices. The sand master is byte-identical;
its supplemental playback gain is halved so recorded wind's quieter lulls remain
clear (base0.0125/swell0.05/max0.065625). Vehicle-contact sand is unchanged.

Pause/rewind/background freeze the voices and schedule, finish fades out,
biome changes stop both, Retry resets the fades/variation and exit frees them.
Existing sound settings/mute apply. The RNG stays outside simulation; no
physics, camera, UI, backend, runtime generation/download/service or dependency
change. Ordinary race rules and five laps remain intact.

The owner's original MP3 is922,018bytes/28.813seconds; SHA256
`c64ada53695793738ea9ba9cc81ba593c1886445860e215359e9b980e1b469a5`.
Original file is read-only for this task and verified unchanged. A local copy and
decoded1,270,656mono frames live under export-excluded
`build/desert_owner_wind/sources`. Filename attribution is TanwerAman; original
licence metadata was not supplied and no CC0 licence is inferred. The shipping
notice/manifest retain this provenance, like existing owner-supplied audio.

New wind WAVs total3,351,732bytes; with retained sand the bank is5,909,576bytes,
88,288bytes above SND42. First/b/c wind SHA256 prefixes are20e84a67/baeb73bd/
090f57eb; sand remainsd818ff6b. Full decode/rebuild reproduces all four hashes.

Changed files:

- `game/track/desert_ambience.gd`: cached variants, shuffle bag, dynamic phase and lower supplemental sand gain.
- `game/assets/audio/ambience/desert_wind.wav`, new `desert_wind_b.wav`/`desert_wind_c.wav`, their imports, `desert_ambience_manifest.json` and `NOTICE.txt`.
- `scripts/build_desert_ambience.py`: pinned owner decode, recorded excerpts and joins; original sand recipe retained.
- `scripts/review_desert_ambience.py`: all variant joins, recording fidelity, native continuity/balance/variation/silence.
- `game/tests/test_desert_ambience.gd`: exact12/14/12-second content fixtures, all-three/no-repeat coverage, native loop crossings and different recorded race sections.
- `docs/DESERT_AMBIENCE.md`, this document, `licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands:

```powershell
Copy-Item -LiteralPath 'C:/Users/ville/Downloads/tanweraman-desert-wind-1-350398.mp3' -Destination build/desert_owner_wind/sources/wind.mp3
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/decode_storm_rain_source.gd -TestArgument @('--source-path=res://../build/desert_owner_wind/sources/wind')"
python scripts/build_desert_ambience.py
python scripts/build_desert_ambience.py --decode
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python scripts/review_desert_ambience.py
Get-FileHash -LiteralPath 'C:/Users/ville/Downloads/tanweraman-desert-wind-1-350398.mp3' -Algorithm SHA256
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
```

Pinned Godot4.7.2 import/headless110/native126/App99 pass. Headless110 and App99
ran after variant implementation; final native126 also covers the subsequent
seam/gain corrections and the same race integration. Six90-second schedules
exercise all variants/no immediate repeats, phases, gains, bounded smooth gusts,
stationary sound, pause/background/retry/mute/finish/biome/exit and unchanged
canonical snapshot. All three actual wind loops and sand cross their boundaries
in native playback. Exact content fixtures replace the superseded37-second
synthetic-wind assertion; all continuity/lifecycle/balance assertions remain.

Final asset joins have zero quantized endpoint step, with local50ms energy ratios
1.141/1.141/1.027 against adjacent regions. Unblended wind interiors correlate
>0.99999999 with the level-matched source; maximum errors<0.00004 are PCM
quantization, verifying no EQ/pitch alteration. All masters/native samples are
unclipped; settled50ms windows remain audible. Two20-second mixes use variants
2/0 and different phases/gust timings, with peaks0.1200/0.1764. Supplemental sand
is8.865dB below the quiet first wind sample over their6/8-second captures.
Paused/muted/finished~0.4-second native samples are exactly silent. These are
isolated ambience recordings; subjective listening/full vehicle balance remain
acceptance, and no phone performance claim is made.

Initial candidates exposed two retained failures: first excerpt's seam energy
ratio1.536 exceeded the existing1.5 maximum; a later native mix had sand only
2.807dB below quiet wind versus the retained>6dB requirement. The builder now
selects seams with matching local energy, and sand gain is halved. Native126 and
the full audit were rerun on the final assets/mix and pass. Initial evidence and
failure values are retained; checks were not weakened.

Evidence: [race mix A](evidence/desert-owner-wind-2026-10-10/mixed0.wav),
[race mix B](evidence/desert-owner-wind-2026-10-10/mixed1.wav),
[measured review](evidence/desert-owner-wind-2026-10-10/review.json), variant/sand/
silence WAVs, event JSONs, focused logs, initial failure receipt and task-only
Git checkpoint/patch under the same directory. Main branch/index and unrelated
work are untouched by the checkpoint.

OPD2403 tablet attached; no phone attached. No Android export/install, device
listening/performance, full Validate, backend change or deployment performed.
Remaining acceptance: restart/rebuild, listen to the two previews and several
Desert retries, then check the actual Android engine/wind balance and rewind/
pause/finish. No UI change, so screenshots are unnecessary.
