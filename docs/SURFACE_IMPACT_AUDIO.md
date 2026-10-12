# Collision, grass and sand audio - 2026-10-08

The owner requests more realistic collisions, matching grass/sand off-track
feedback and desert sand/small stones striking the underside that follow speed
and acceleration. This presentation-only slice replaces the rejected impact and
particle derivatives and implements SND08-SND10, refining SND04-SND07 and
supporting G01/R01, Q01 and V06.

The owner's subsequent desert correction replaces spaced pebble hits there
with a continuous granular underbody stream. [Current desert mix and checks](DESERT_CONTINUOUS_AUDIO.md)
supersede this page's desert event cadence; other-biome ground feedback and the
immediate collision timing remain. The bank has 46 clips and 22 bounded voices.

The owner's subsequent timing correction starts collisions directly from the
post-simulation observer and removes the queued render wait. It also front-loads
the existing chassis transient. [Measured timing, regressions and current bank](EFFECT_TIMING.md)
supersede the render dispatch and chassis asset/hash/byte count below; the other
44 clip hashes and the 21-voice bound remain unchanged.

| Requirement | Current behavior |
| --- | --- |
| SND08 | Actual collision impulse chooses a damped light bump, medium mechanical crunch or heavier body hit/settling. Gain follows severity; four pitch variants and a 120-230 ms cooldown avoid identical rapid wall hits. Landings use suspension/body foley rather than collision crunch. |
| SND09 | Read all four selected-car wheel positions using its actual wheelbase/track width. Partial road/grass/sand contact blends materials before the car centre leaves the road. Grass has fuller recorded rolling/rustle; sand/dirt uses granular driving and low rolling rumble in every biome. Pavement squeal/rolling cease when the wheels have left pavement. Kerbs remain firm contact. |
| SND10 | Sand rumble, granular spray and short damped underside-stone taps change with speed. Pedal demand, smoothed measured acceleration and actual slip strengthen spray and increase stone cadence/energy; reverse uses its driving pedal. Stationary revving cannot throw stones. |
| SND05/Q01 | Ground contact stops during jumps, rollover and countdown; pause freezes all voices. Rewind/retry clear incident/debris/acceleration history. Two independent debris voices cannot truncate one of four body-event voices. The race has 21 bounded players: six engine, nine rolling/material/wind/scrape and six one-shot. Stone interval is at least 120 ms, with bounded catch-up. |
| V06/SND06 | Local cleared sources, source/derivative hashes, documented edits and shipping credits. No runtime synthesis, generation/network call, dependency, physics/rules/config/content change or player-file migration. |

The current bank contains **45** mono 44.1 kHz 16-bit PCM clips occupying
**9,399,550 bytes**, an increase of **1,104,576 bytes**. Nine prior derivatives
change and `sand_roll.wav` is added. All **35** other clip hashes, including all
30 engine clips and the existing pavement tire recording, are identical to the
task-start bank. Active loops have lossless PCM imports and exact frame limits.

The previous grass loop existed but sampled the car centre and used a thinner
high-pass cut. This correction improves the source/mix and samples each wheel;
it does not claim grass was entirely absent before the change. The former grit
was edited pebble footsteps and the impacts were door/trunk slams.

## Cleared source material

Three additional CC0 sources use the authors' public HQ MP3 previews, decoded
offline with the pinned engine. They are compressed source previews, not
lossless production masters:

- [Collision by qubodup](https://freesound.org/people/qubodup/sounds/332058/): designed mechanical collision derived from a CC0 drone recording; cut, filtered/transposed into severity banks and layered with existing CC0 Nox body movement. It is not a recording of a real car crash.
- [gravel drive.wav by cognito perceptu](https://freesound.org/people/cognito%20perceptu/sounds/97605/): recorded car-on-gravel driving supplies low rolling and granular beds. The sand spray mixes a small amount of the existing CC0 Nox dirty-ground recording. This is designed sand presentation from gravel/ground foley, not a claimed dedicated sand test-car recording.
- [Tapping things with stones.wav by KALeigh0218](https://freesound.org/people/KALeigh0218/sounds/655924/): stone contacts on surfaces including metal, cut/high-pass filtered into short damped underside taps. Source sound design and spectral filtering, not a new under-car field recording.

Grass continues to use the existing cleared Nox vehicle-on-grass recording, with
a longer selected segment and fuller low/mid texture. Exact source/derivative
hashes are in `game/assets/audio/vehicles/manifest.json`; credits ship in
`NOTICE.txt`. License HTML, encoded sources, decoded float samples and decode
metadata remain in ignored `build/vehicle_audio_sources/`, outside exports.
Pavement tire attribution remains audible-edge (Tom Haigh), edit by qubodup,
CC BY 3.0, including previews that contain it.

Rebuild order: `python scripts/fetch_surface_audio.py`, the pinned Godot
`TestScript -ScriptPath res://tests/decode_surface_sources.gd`, then
`python scripts/fetch_surface_audio.py --finalize`, then
`python scripts/build_vehicle_audio.py`. The existing original bank-source fetch
is still required for a fresh workspace. `surface_audio_mastering.py` authors the
replacement derivatives as part of every ordinary bank rebuild.

## Actual verification and evidence

All Godot commands use `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1` and **4.7.2.stable.official.ed1daf0bf**, never the PATH alias.

| Actual command suffix / command | Result |
| --- | --- |
| `python scripts/fetch_surface_audio.py` | Three public CC0 previews fetched and license pages checked/saved; no account, purchase or generation service. |
| `TestScript -ScriptPath res://tests/decode_surface_sources.gd` | Three sources decoded at 44.1 kHz with exact metadata; first sandbox run could not open the existing external user log. Normal Windows execution succeeds. |
| `python scripts/fetch_surface_audio.py --finalize` | Three decoded WAV sources and original encoded/decoded SHA-256 pinned. |
| `python scripts/build_vehicle_audio.py` | 45 clips/9,399,550 bytes; maximum asset peak -1.514 dBFS. |
| `Import` | Initial/final exit 0, including new layer/script imports. One intervening retry failed on a concurrent `track_browser.gd` undeclared `test_histograms` edit; that unrelated edit was corrected independently. |
| `TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | 1,438 checks, zero failures, including bank integrity, bounded voices, lifecycle, race retry and canonical equivalence. |
| `TestScript -ScriptPath res://tests/test_desert_audio.gd` | 25 checks, zero failures; existing material/tire/lifecycle/replay contract. |
| `TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | 67 checks, zero failures: seven material classes, partial edge contact, all five actual vehicle spans, speed, held pedal and measured acceleration, reverse, event-pool isolation, severity, stop/air/roll/countdown/pause/rewind and exact 960-tick state equality. |
| `TestScript -ScriptPath res://tests/capture_surface_impact_audio.gd -Graphical` | 14 checks, zero failures; four actual desktop captures and an exactly silent dry tire-bus proof. Final maximum mix peak -2.418 dBFS; last half-second of every capture exactly zero. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/surface-impact-audio-2026-10-08/loop-continuity.json` | 38 loops, zero failures, including three repetitions, embedded-gap and wrap checks. |
| `python scripts/review_surface_audio.py` | Four actual audible/unclipped mixes; exactly silent pause tails, preserved engine hashes and measured speed/tractive-effort response. `capture-levels.json` pins measurements and capture hashes. |
| `TestApp` | 99 checks, zero failures. |
| `TestRewind` | 57 checks, zero failures. |
| `TestHandling` | 88 checks, zero failures, including historical exact replay invariants. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | Initial 359/final 360 scripts, zero failures. |
| `Doctor` | DN2103 attached; attachment alone is not a phone audio test. |
| `python docs/evidence/surface-impact-audio-2026-10-08/make_checkpoint.py` | Task-scoped patch and 51-file SHA-256 inventory; `git apply --reverse --check --ignore-whitespace` succeeds. |
| `git diff --check -- DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md licenses/ASSETS.md` | Final exit 0; an added EOF blank line was corrected. Existing CRLF normalization notices remain. |

[Listen to the actual game mixes](evidence/surface-impact-audio-2026-10-08/audition.html):
full desert vehicle, isolated desert surface mix, grass/sand/pavement transition
and light/medium/heavy contacts. No visible product UI change; audio is the
presentation evidence.

The first combined test/capture process produced invalid audio because thousands
of synchronous behavioral-test audio commands were still queued. The listening
review rejected its very quiet/non-silent output. Those failed files are retained
under `failed-queued-capture/`; they are not acceptance evidence. The dedicated
capture script runs in a fresh process and checks audible peak/headroom and exact
pause silence before accepting previews. No check was weakened to accept them.
An intervening capture was interrupted after the tire-check loop repeatedly
requested the WAV data property. Caching that PCM buffer once fixed the diagnostic
cost; the final clean capture passes. The game runtime never used that loop.

## Changed files and acceptance limits

Runtime: `game/vehicle/vehicle_audio.gd`, new `surface_audio_model.gd`/UID,
the nine replacement WAV/imports, new `sand_roll.wav`/import and bank
manifest/notice. Tooling: `scripts/build_vehicle_audio.py`, new
`surface_audio_mastering.py`, `fetch_surface_audio.py`, `review_surface_audio.py`,
offline decode script/UID, new behavioral/capture scripts/UID and the existing
vehicle-audio bank/voice expectations. Documentation: this file, links in
`VEHICLE_AUDIO.md`/`DESERT_AUDIO.md`, provenance/status/phase notes and the task
evidence/checkpoint inventory.

No Android export/install, phone speaker/headphone listening, full Validate,
backend rollout or production deployment was performed. Owner listening for
impact character, the sand/grass textures, underside-stone balance and transitions
remains open, as do phone memory/voice/thermal measurements and audio-focus
listening through pause, backgrounding, rewind and ads. This is a local sound
design revision for audition; automated checks do not establish realism or AAA
quality. Existing unrelated workspace work is preserved in the scoped review
patch and SHA-256 checkpoint without modifying the shared Git index.
