# Subtle Grass nature sounds, 2026-10-10

SND41 implements the owner's follow-up to SND39: quiet insects and rustling leaves
under Grass birdsong. G01/R01 preserve canonical driving; Q01 covers measured
verification, provenance and a scoped checkpoint.

`GrassNature` adds two race-owned Vehicle-bus voices only for `pine` (Grass).
The existing cleared 40-second Clarisse cicada recording is reused unchanged at
0.035–0.075 gain, with a slow opening fade and new target levels every6–15 seconds.
Each race/Retry chooses a different playback offset and target level. Occasional
recorded leaf rustles start after4–10 seconds, then leave8–20 seconds of silence
after each complete phrase. Rustle gain is0.09–0.15, with pitch0.90–1.02 and a slow
250ms attack/450ms release. The nature RNG is independent of birds and simulation.
The existing bird assets, ordering, intervals and gain are unchanged.

Pause/rewind and OS suspension freeze both layers and their schedules. Finish
fades both out within0.5 seconds; biome changes stop them immediately; exit frees
the two voices. Retry resets their fades, phase, target and rustle timing. Existing
sound volume/mute covers both. No new menu labels/settings, dependencies, runtime
downloads/services, physics or backend contracts are introduced.

The leaf source is the CC0 option of
[Random Sounds Samples](https://opengameart.org/content/random-sounds-samples),
by Augmentality (Brandon Morris), uploaded by HaelDB. It is recorded leaf-rustling
foley, not a new wind field recording. The full1.402-second phrase is decoded
offline with pinned Godot, downmixed, cleaned of DC/rumble, softened above5.5kHz,
faded at the edges and peak capped at−8dBFS (actual RMS−30.426dBFS). The new
mono44.1kHz16-bit PCM asset is123,720bytes. `grass_nature_manifest.json` pins
source/decoded/derivative hashes and the unchanged insect asset hash. Existing
Clarisse/CC0 provenance remains in `ambience/NOTICE.txt` and `manifest.json`.

Changed files:

- `game/track/grass_nature.gd` and `.uid`: two voices, independent RNG and lifecycle.
- `game/core/game.gd`: seven added lines for setup, presentation and Retry.
- `game/assets/audio/ambience/grass_leaves.wav`, `.wav.import`, `grass_nature_manifest.json` and `NOTICE.txt`.
- `scripts/build_grass_nature.py`, `scripts/review_grass_nature.py`.
- `game/tests/decode_grass_leaves.gd`, `test_grass_nature.gd` and their `.uid` files.
- `licenses/ASSETS.md`, this document, `docs/GRASS_BIRDS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands:

```powershell
python scripts/build_grass_nature.py --fetch
python scripts/build_grass_nature.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_nature.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_grass_nature.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_birds.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_night_ambience.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python scripts/review_grass_nature.py
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
```

Pinned Godot4.7.2 import passes. Final grass-nature headless107/native119,
birds295/night25/App99 checks pass. Six90-second schedules vary phase, swells and
rustles; bounded gains/voice count, complete phrases, pause/background/retry/
finish/biome/mute/exit and actual race integration are covered. Canonical snapshot
is unchanged. The repeated offline rebuild reproduces the leaf hash exactly;
all three bird hashes and the existing insect hash are verified unchanged.

Native isolated recordings measure insects−48.435dBFS RMS and leaves−50.427dBFS
RMS versus birds−33.894dBFS:14.541/16.533dB lower over the respective complete
8/3/6-second samples. This is sample-level evidence, not a claim about every
moment or a full engine/vehicle mix. The insect capture crosses its actual loop
boundary. Two20-second combined mixes have different insect phases and rustle
timings, with peaks0.1953/0.2039 and zero clipped samples. Paused/muted/finished
~0.4-second native captures are exactly silent. No subjective listening claim.

The first native run had119checks/1failure: fast-forwarded schedule checks queued
decoder starts/stops without rendered frames, delaying the insect recording and
its loop crossing. The fixture now disables output only during mathematical
fast-forward checks and enables real playback for the wall-time capture. The
loop-crossing assertion is retained and final native119 passes. Runtime output
defaults to enabled on graphical devices and disabled headlessly. Initial
sandbox ADB inventory access failed; approved read-only inventory then succeeded.
Existing unrelated editor/vehicle work was preserved.

Evidence: [combined mix A](evidence/grass-nature-2026-10-10/mixed0.wav),
[combined mix B](evidence/grass-nature-2026-10-10/mixed1.wav),
[measured report](evidence/grass-nature-2026-10-10/review.json), component/silence
WAVs, event JSONs, focused logs and `task-only.patch`/`checkpoint.json` in the same
directory. The isolated Git checkpoint leaves the main index/branch untouched.

One authorized OPD2403 tablet is attached; no phone is attached. No Android
export/install, device listening, full Validate, backend change or deployment was
performed. Remaining acceptance: restart/rebuild, listen across Grass retries
with vehicle sound on the actual Android device, and judge whether the insects
and rustles remain subtle. UI is unchanged, so screenshots are unnecessary.
