# Vehicle audio replacement — 2026-10-06

The owner's 2026-10-08 collision and surface revision now uses severity-selected
impacts, four-wheel material blends, fuller grass and speed/acceleration-driven
sand rolling/spray with separate underside-stone voices. The bank has 45 clips
and the race voice bound is 21. [Current behavior, actual audio and verification](SURFACE_IMPACT_AUDIO.md)
supersede the older collision/surface descriptions and voice counts below.

The owner subsequently found intermittent playback in the initial masters. The
resampler overflow was reproduced and fixed; all loops now pass dropout and wrap
checks. [Correction, actual checks and continuous previews](VEHICLE_AUDIO_CONTINUITY.md)
supersede the initial listening captures and continuity assumptions below.

The owner's desert correction now replaces every desert tire/tread bed with a
dedicated sand spray and pebble-scatter mix. The current bank has 44 clips and a
17-voice race limit. [Desert audio behavior and evidence](DESERT_AUDIO.md) supersede
the initial generic loose-ground presentation described below.

The owner requested removal of the current soundtrack and AAA-level high-quality
car sounds. The race now creates a recorded vehicle mixer instead of the generated
soundtrack or the old procedural tire player. The prior soundtrack, its native
libraries/build sources and diagnostic test are archived outside the export root
at `archive/retired-soundtrack-2026-10-06/`.

## Requirements and behavior

This slice implements owner requirements SND01–SND06 and supports G01/R01
driving feedback, Q01 bounded mobile presentation and V06 asset provenance.

| ID | Implemented behavior |
| --- | --- |
| SND01 | No generated soundtrack playback or native music extension in the active Godot project. Historical sources retained; old development music commands explain retirement. |
| SND02 | Compact, pickup, classic sports, Formula and kart have authored engine banks. Three RPM layers per car, with separate load/coast variants, equal-power logarithmic crossfades, smoothly changing pitch/load and startup gain. |
| SND03 | Presentation-only rev/gear model responds to speed, throttle, braking in reverse, lift-off and airborne/handbrake load. Geared cars have shift cut/shift sound and hysteresis; kart has one gear. No changes to physics, input logs, vehicle configs, rules, track compiler or records. |
| SND04 | Recorded tire slip, road rolling, dirt/sand and grass layers; original wind/water beds. Desert uses granular scrub; wet roads/puddles use spray. Airborne tire/rolling layers silence immediately. Actual collision impulses, jump landings and kerb motion drive bounded body events. |
| SND05 | Pause freezes playback and suppresses incidents; countdown allows engine response with stationary tire/road layers. Retry and rewind discard old incidents/reset drivetrain. Six engine loops, six surface/wind loops and four event slots bound each race to 16 voices. |
| SND06 | Local cleared masters, hashes and derivative descriptions; lossless 44.1 kHz mono 16-bit PCM import. Vehicle dynamics compression, -2 dBFS vehicle ceiling and -1 dBFS master ceiling. Credits/manifest included in the Android export configuration. |

Forty mastered clips occupy **7,971,368 bytes** (about 7.6 MiB), with maximum
asset peak -1.514 dBFS. Runtime retains the selected vehicle bank, not every car's
engine bank. Masters were cut, filtered, transposed, loop-crossfaded, RMS/peak
mastered and dithered offline. `tire.wav` retains the existing silent-endpoint
invariant with a 2 ms taper. Old `TireAudio.scrub_amount` diagnostics remain intact.

The engine RPM/gears are sound design controls, not a physical transmission or
an assertion about the RPM of every source recording. The Formula/kart voices
use transformed car/motorcycle recordings; body impacts use edited body/door
recordings. Wind and spray are authored noise beds. This is not a dedicated
multimicrophone motorsport dyno library. AAA is the requested ambition; owner ear
acceptance and physical-phone listening/performance are still required.

## Provenance and files

The source/derivative ledger is
[`game/assets/audio/vehicles/manifest.json`](../game/assets/audio/vehicles/manifest.json);
shipping credits are
[`NOTICE.txt`](../game/assets/audio/vehicles/NOTICE.txt). The root ledger
[`licenses/ASSETS.md`](../licenses/ASSETS.md) is updated.

- Nox Sound Design [Essentials Series](https://nox-sound-design.itch.io/essentials-series-sfx-nox-sound): CC0 engine, rolling and body masters.
- Joseph SARDIN [AC Cobra Engine](https://bigsoundbank.com/ac-cobra-engine-s0534.html): CC0 classic engine source.
- DenisChardonnet [Motor car #1](https://bigsoundbank.com/motor-car-1-s0290.html) and [Motorcycle](https://bigsoundbank.com/motorcycle-s0281.html): CC0 Formula/kart source material.
- audible-edge (Tom Haigh), loop edit by qubodup, [Car tire squeal skid loop](https://opengameart.org/content/car-tire-squeal-skid-loop): [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/); modifications/attribution documented in the shipping notice and review page.

No asset purchase, paid generation, new runtime dependency or runtime audio/API
request was added. NumPy already present on this development machine is used only
by offline mastering/review scripts. The large Nox archive was read with bounded
HTTP range requests; only selected masters were downloaded to ignored build
storage. Public library download session values are not shipping data.

Runtime files: `game/vehicle/vehicle_audio.gd`, `vehicle_audio_model.gd`,
`tire_audio.gd`, `game/core/game.gd`, `game/default_bus_layout.tres`,
`game/export_presets.cfg`, `game/assets/audio/vehicles/*` and generated `.uid`s.
Tool/test files: `scripts/fetch_vehicle_audio.py`, `build_vehicle_audio.py`,
`review_vehicle_audio.py`, `scripts/dev.ps1`, `game/tests/test_vehicle_audio.gd`.
Historical `game/music/*`, `game/tests/test_music.*`, `native/music/*` and
`scripts/build_music.ps1` moved to the archive. No player files were touched.

## Actual commands and results

All engine commands used `scripts/dev.ps1` and
`4.7.2.stable.official.ed1daf0bf`, never the older PATH alias.

| Command | Actual outcome |
| --- | --- |
| `python scripts/fetch_vehicle_audio.py` | 19 cleared source WAV masters retrieved; WAV type checked by mastering, source SHA-256 pinned. Early free-library endpoint/key discovery and wrong BSB WAV path failures corrected; actual BWF masters fetched. No purchase. |
| `python scripts/build_vehicle_audio.py` | 40 final bank clips, 7,971,368 bytes. Rebuilt after adding 32-bit PCM handling, forcing lossless import and preserving the tire seam invariant. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import` | Final import passes. Initial sandbox attempt hit stale extension/certificate-store access errors; normal Windows execution completed the import. |
| `… scripts/dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | Final **1,418 checks, 0 failures**. Includes bank hashes/PCM/headroom, equal-power weights, drivetrain lifecycle, reverse, pause/countdown, asphalt/desert/wet/puddle feedback, actual impacts, airborne silence, rewind, real race creation/retry, and exact simulation snapshots after 960 ticks with/without audio. |
| `… scripts/dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio.gd -Graphical` | **1,432 checks, 0 failures** after tire fix; five actual master-bus recordings captured and checked audible/unclipped. Subsequent puddle classification adds one final headless check; previews use no track and are unaffected. |
| `… scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd` | **306 scripts, 0 failures** at that run. Concurrent unrelated work can change the count. |
| `… scripts/dev.ps1 TestHandling` | Final **88 checks, 0 failures**, including exact historical replay checks. Initial silent-loop-endpoint failure corrected by mastering the replacement tire clip; the existing test was not weakened. |
| `… scripts/dev.ps1 TestApp` | **99 checks, 0 failures**; isolated app/race/retry/records flow. |
| `… scripts/dev.ps1 TestRewind` | **57 checks, 0 failures**. |
| `… scripts/dev.ps1 Doctor` | DN2103 attached (`PRQKU4U4PREQNRWG`). This only checks attachment/tool prerequisites. |
| `python scripts/review_vehicle_audio.py` | Five audible, unclipped mixes; last half-second of each is exactly silent after pause. Local listening page and measured levels saved. |
| `git diff --check -- game/core/game.gd game/vehicle/tire_audio.gd game/export_presets.cfg scripts/dev.ps1` | Exit 0; existing Windows CRLF normalization notice retained. |
| `python build/make_vehicle_audio_checkpoint.py` then `git apply --reverse --check --ignore-whitespace docs/evidence/vehicle-audio-2026-10-06/scoped-change.patch` | Final exit 0: task-scoped text changes, 43 tracked archive moves, and a SHA-256 inventory of 96 new source/import/asset/review files. WAV bytes remain separate pinned artifacts. Initial review patch lacked an EOF marker for the listening HTML; corrected before the successful check. |

Corrected intermediate failures are retained in the evidence log copies. Import
and tests were run with normal Windows certificate/audio access after sandbox
denial. Full Validate, Android export/install, phone audio listening, thermal
profiling and backend deployment were **not** performed.

## Review evidence and remaining acceptance

[Listen to all five actual engine mixes](evidence/vehicle-audio-2026-10-06/audition.html).
Each eight-second capture demonstrates idle, acceleration/shift, coast/brake,
slip, impact and pause. Numeric evidence is
[`capture_levels.json`](evidence/vehicle-audio-2026-10-06/capture_levels.json).
The previews carry the recorded tire attribution. There are no visible game UI
changes in this slice, so audio captures are the relevant presentation evidence.

Source changes and archive moves are recorded in the scoped review patch/hash
inventory under `docs/evidence/vehicle-audio-2026-10-06/`; unrelated existing and
concurrent work is preserved. The checkpoint is a validated review patch plus
artifact hashes; no Git commit or shared-index change was made. This is not a
backend/physics rollout.

Remaining acceptance: owner listening for engine character, shift/loop transitions
and mix balance; DN2103 speaker/headphone audition in every biome; pause/focus/ads
audio focus; long races/rewind/retry listening; Android packaging verification and
20-minute voice/memory/thermal measurements. Desktop capture levels and automated
checks do not establish the requested AAA listening quality or phone acceptance.
