# Desert sand and flying-rock audio — 2026-10-06

The owner's 2026-10-08 follow-up replaces the old footstep grit and thin sand bed
with recorded granular driving, rolling rumble and damped underside stone taps.
Four-wheel contacts and speed, throttle, measured acceleration and slip drive
the mix. [Current correction and actual previews](SURFACE_IMPACT_AUDIO.md)
supersede the original sand/grit assets and 17-voice description below.

The owner requests no tire sound in Desert, with flying-rock and sand feedback
instead. SND07 refines SND04 material audio, SND05 lifecycle, Q01 voice bounds and
V06 provenance. Desert immediately mutes tire squeal, tread/road, generic loose
ground and grass loops, including old transition tails. A dedicated sand spray
loop and three short pebble-scatter variants replace them.

Sand is audible during ordinary movement and grows with speed/slip; sandy
shoulders strengthen it. The ground classes match the existing desert sand
particles/grooves (road, grass/soil and kerb cells 0/1/2/5). Debris cadence derives
from traveled presentation distance, with varied spacing/pitch/gain and a 120 ms
minimum interval. The existing four one-shot slots bound all event playback.
Nothing writes simulation state, input logs, physics, handling, rules or track data.

New grains stop when stationary, airborne, rolled, paused, counting down or on
water/puddles. Water retains splash feedback. Retry/rewind clear particle history;
existing short gravel tails may finish after the last ejection. Other biomes keep
their existing tire mix. Initial/muted loop volume now uses true zero gain; the
dry-desert tire bus is measured digitally silent.

Assets: `sand.wav` is filtered Nox dirty-ground driving foley with low vehicle tones
removed. `grit_0/1/2.wav` use Nox Iceland black-pebble recordings cut, filtered and
mastered as short stone sprays. These are designed gravel foley, not exact car-rock
recordings. All three added masters are CC0 from the already-used
[Nox Sound Design Essentials Series](https://nox-sound-design.itch.io/essentials-series-sfx-nox-sound),
fetched as bounded archive ranges with no purchase. The current manifest pins 22
source recordings and 44 derivatives; shipping credits/asset ledger are updated.

The four new clips add **323,606 bytes**: total bank **8,294,974 bytes**, with maximum
asset peak -1.514 dBFS. All **40 previous clip hashes remain identical**. The added
sand loop changes the explicit voice limit from 16 to **17** (six engine, seven
material/wind, four event slots); no new event players or unbounded bursts.

## Actual verification

All Godot commands use `scripts/dev.ps1` and
`4.7.2.stable.official.ed1daf0bf`.

| Actual command | Result |
| --- | --- |
| `python scripts/fetch_vehicle_audio.py` | Three added CC0 pebble masters; 22 source masters verified/pinned. Existing sources reused; no purchase. |
| `python scripts/build_vehicle_audio.py` | 44 PCM clips; 8,294,974 bytes. Existing 40 clip hashes identical to the task-start manifest. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import` | Exit 0, including new clips and script UID. |
| `… scripts/dev.ps1 TestScript -ScriptPath res://tests/test_desert_audio.gd -Graphical` | **29 checks, 0 failures**: material classes, exact tire gain silence, moving/slide/stop/airborne/roll/pause/countdown/water behavior, cadence bounds, retry/rewind and exact 960-tick simulation equivalence. Actual twelve-second mix and tire-bus capture saved; tire bus peak exactly 0. |
| `… scripts/dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,434 checks, 0 failures**. Golden clip count and explicit bounded voice count updated for the approved four clips/one loop; feedback/replay contracts preserved. |
| `… scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd` | **314 scripts, 0 failures** at this run. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/desert-audio-2026-10-06/loop-continuity.json` | **37 looped assets, 0 failures**, with three repeats, gap and wrap-boundary checks. |
| `python scripts/review_desert_audio.py` | Audible/unclipped full mix, exactly silent tire recording and paused tails; local review page and numeric levels saved. |

[Listen to the actual desert mix](evidence/desert-audio-2026-10-06/audition.html).
Actual logs, source hashes and a task-scoped review patch are in that directory.
Source files: `game/vehicle/vehicle_audio.gd`, `game/tests/test_vehicle_audio.gd`, new
`game/tests/test_desert_audio.gd`/`.uid`, `scripts/build_vehicle_audio.py`,
`scripts/fetch_vehicle_audio.py`, new `scripts/review_desert_audio.py`, new sand/grit
WAV/import metadata, bank manifest/notice and provenance/status notes. No visible
game UI changes; audio is the presentation evidence. Concurrent work preserved;
no shared-index or commit mutation.

No phone attachment check, phone audio/performance test, Android export/install,
full Validate or backend deployment was performed. Owner listening for sand/rock
character and balance, phone speakers/headphones and performance remain unverified.
