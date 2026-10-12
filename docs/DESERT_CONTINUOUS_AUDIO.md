# Continuous desert sand and underbody noise - 2026-10-08

Follow-up SND42 adds independent ambient wind and wind-blown dune sand that play
at rest as well as during driving. This vehicle-contact audio remains intact.
[Desert ambience implementation and actual audio checks](DESERT_AMBIENCE.md).

The owner rejected the regular separate desert pebble hits and requests the
steady noise of sand and small stones striking the underside during racing.
SND12 supersedes the desert one-shot portion of SND07/SND10. The follow-up SND13
requires a small speed-frequency change and sand quieter than the engine. SND05/SND11, G01/R01,
Q01 and V06 remain supported.

Desert now mixes a **continuous granular underbody texture**, recorded rolling
rumble and a quieter sand spray. The distance-spaced grit one-shots are disabled
there, including old event tails when entering Desert. The new layer grows with
speed, throttle/actual acceleration demand and sliding; reverse uses its driving
pedal. All four selected-car wheel contacts determine how much sand is heard.
Stationary revving, airborne/rolled wheels, countdown, water and blocked surfaces
cannot emit the continuous dry-grain layer. Pause freezes its playback; rewind
and retry clear/reset presentation history. Collision audio still starts directly
from the collision observer with its existing timing/guards.

The owner rejected the first continuous candidate's character/balance. The final
mix makes recorded granular driving dominant (75%) with subdued grain detail
(25%), reduces the bright high end with a 4.4 kHz low-pass and levels larger
recorded contacts into a steady swish. All three desert ground layers sit below
the engine; their gain also reduces on lift-off. Speed smoothly moves their shared
pitch from 0.94 to 1.08 across 0-46 m/s. Between 29 and 90 km/h the change is about
5.4%; throttle changes intensity without revving the ground pitch at the same
speed. Final bank revision is `desert-tone-balance-5`.

The new `sand_debris.wav` is a **9.9-second** seamless mono 44.1 kHz 16-bit PCM
loop. Hundreds of irregular short, damped stone grains overlap with recorded
granular driving texture; short-scale detail remains while larger clumps are
leveled. This texture is baked offline with a fixed seed. The game plays one
ordinary loop, not hundreds of event voices or runtime synthesis/random grains.
No periodic one-second amplitude gate is used. The earlier sand spray remains at
40% of its former desert gain before the additional engine-relative terrain
gain, so the continuous fine stream carries the detail underneath the engine.

This changes only Desert presentation. Non-desert grass/loose-ground event and
material behavior, the previous 45 audio master hashes, collision attacks,
handling, physics/rules/track identities and player files are retained. One added
loop changes the total bank to **46 clips / 10,267,482 WAV bytes** (+873,224 bytes)
and the race player bound to **22**: six engine, ten material/wind/scrape loops and
six event slots. The two event slots for non-desert gravel remain bounded.

## Source and listening evidence

No new external source, purchase, generator/service or runtime dependency is
introduced. The added loop derives from the previously cleared CC0 KALeigh0218
stone-contact recording and cognito perceptu gravel-driving recording; source
URLs and encoded/decoded/derivative hashes remain in the bank manifest. Grain
cuts/damping, pitch/level variation, overlap, envelope shaping, filtering,
crossfade, mastering and dither are documented in
`scripts/surface_audio_mastering.py` and the shipping `NOTICE.txt`. It is designed
granular foley from recordings, not a claimed dedicated under-car field recording.

[Listen to the new mix](evidence/desert-continuous-audio-2026-10-08/audition.html):
18-second steady sand at 90 km/h with engine muted, then the full vehicle mix
with acceleration/coast/power/sliding/stop/pause. The earlier actual recording is
retained for historical comparison, with its different timeline stated. Captures
use the real desktop mixer in a fresh process, not a batch of synchronous audio
tests queued before recording. Both captures cross an actual loop wrap and have
no discrete grit events; the dry tire bus remains exactly silent. Simultaneously
recorded diagnostic Engine and SandReview buses establish their relative levels;
the temporary SandReview bus forwards to the usual Vehicle dynamics and is never
added to shipping bus settings.

The final source's 20 ms RMS envelope has coefficient of variation **0.086** across
three repetitions and zero windows below 15% of the median. The actual 15-second
steady native segment has coefficient **0.150**, zero quiet windows and peak
**-18.704 dBFS** with the engine muted. The complete driving segment has peak
**-6.878 dBFS**. Sand RMS is **13.27 dB below the engine while coasting**, **16.15 dB
below under power** and **14.47 dB below during the selected slide**, measured
upstream of their shared Vehicle dynamics. The last half-second
of each recording is exactly silent after pause. These are continuity/mix
measurements, not subjective realism or phone-listening approval.

## Actual commands and outcomes

Every Godot command uses `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1` and **4.7.2.stable.official.ed1daf0bf**.

| Actual command / suffix | Actual outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py` | 46 clips/10,267,482 bytes; maximum asset peak -1.514 dBFS. All previous 45 hashes exact. |
| `Import` | Exit 0 including the new lossless loop and mixer code. |
| `TestScript -ScriptPath res://tests/test_desert_audio.gd` | 25 checks, zero failures; existing material/tire/lifecycle/equivalence checks now assert a continuous stream with no separate hits, per owner override. |
| `TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | 67 checks, zero failures; all five wheel spans, partial contact, speed/load/reverse, collision isolation, stop/air/roll/pause/countdown/water/rewind and exact 960-tick simulation equality. |
| `TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | 1,442 checks, zero failures; bank hashes/PCM/headroom, new explicit 22-player bound and app audio lifecycle. |
| `TestScript -ScriptPath res://tests/test_continuous_desert_audio.gd` | 28 checks, zero failures; ten seconds without recurring events, one playback identity, bounded slight speed-tone change, no pedal-driven tone change, speed/power/reverse, immediate collisions, non-desert preservation and old-event-tail/material/stop suppression. |
| `TestScript -ScriptPath res://tests/capture_continuous_desert_audio.gd -Graphical` | 16 checks, zero failures; actual loop wraps, zero grit events, dry tire silence, final pause silence and saved same-clock engine/sand references. |
| `TestScript -ScriptPath res://tests/test_effect_timing.gd` | 40 checks, zero failures; immediate collision dispatch and all seven contact attacks preserved. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | Initial 368/final 370 scripts, zero failures. |
| `TestApp` / `TestRewind` | 99 / 57 checks, zero failures. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/desert-continuous-audio-2026-10-08/loop-continuity.json` | 39 loops, zero failures, including wrap/gap/three-repeat checks. |
| `python scripts/review_continuous_desert_audio.py` | Continuous source/native PCM, exact 45 prior hashes and sand quieter than engine in coasting/power/slide references verified; final report and listening page saved. |
| `Doctor` | No device attached in this check; no phone audio/performance test. |
| `python -m py_compile scripts/surface_audio_mastering.py scripts/review_continuous_desert_audio.py` | Exit 0. |
| `git diff --check -- DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md licenses/ASSETS.md` | Exit 0; existing CRLF normalization notices retained. |
| `python docs/evidence/desert-continuous-audio-2026-10-08/make_checkpoint.py` | 32 pinned files/43 retained logs; task-only reverse patch check exits 0. |

The old desert cadence assertions are replaced because the owner explicitly
rejects that behavior; material/lifecycle/replay/voice/headroom invariants are
retained and continuous PCM evidence strengthens the new contract. No failing
physical invariant is removed or weakened. No visible product UI change; native
audio captures are the presentation evidence.

The rejected bright/loud first candidate is retained under `rejected-loud-r1/`
and its exact source/settings under `before-tone-balance/`. A softer candidate
still had excessive recorded envelope variation (CV 0.368); the final full-bed
envelope shaping lowers it to 0.086 without relaxing the continuity check.
Intermediate native references remain under `candidate-before-leveling/`. A fast
headless timing run reported 155 queued shutdown references; allowing 100 ms for
the asynchronous audio stop queue to drain gives the final clean 40-check exit.
That wait is confined to test cleanup and changes no runtime/canonical behavior.

## Changed files and remaining acceptance

Runtime: `game/vehicle/vehicle_audio.gd`. Offline assets/tooling:
`scripts/surface_audio_mastering.py`, bank revision in
`scripts/build_vehicle_audio.py`, new `sand_debris.wav`/import, manifest/notice
and new `scripts/review_continuous_desert_audio.py`. Tests: existing
`test_desert_audio.gd`, `test_surface_impact_audio.gd`, `test_vehicle_audio.gd`,
new continuous behavior/capture scripts and their UIDs, and the explicit
asynchronous-stop drain in `test_effect_timing.gd`. Docs: this file, links in
`DESERT_AUDIO.md`/`SURFACE_IMPACT_AUDIO.md`, status/phase/provenance and the scoped
review checkpoint. Existing concurrent changes are preserved; no shared Git
index or commit mutation.

Restart the running game to load the new bank/mixer. Owner listening for noise
character and balance remains open. No phone was attached for the final device
check; phone speakers/headphones, audio focus and performance/thermal acceptance
were not tested. No Android export/install, full Validate, backend action or
production deployment was performed. Digital continuity proves a sustained
stream, not subjective real-world accuracy.
