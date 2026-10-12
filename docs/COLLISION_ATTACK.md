# Visible wall contact and immediate impact attack - 2026-10-08

The owner reports a noticeable **100-200 ms** delay when driving into a wall and
requires immediate collision audio with no brief silence. SND14-SND15 refine
SND08/SND11 and preserve SND05, G01/R01/Q01/V06.

The larger delay was reproduced before audio playback: the compact's drawn nose
extends **1.98352 m** forward while its accepted circular collider has radius
**1.364 m**. At an initial 4 m/s, visible wall contact occurs on tick **62**, while
canonical response occurs on tick **81**: **158.33 ms** later. The earlier direct
canonical callback/4 ms attack correction did not address that geometric gap.

The new read-only `VisibleContactAudio` derives a convex planar outline from the
selected vehicle's actual mesh vertices and existing scale, once per race. A
bounded perimeter/material check observes current intersection with solid cell4
on the correct driving layer. Meaningful inward contact cues sound on that
visible-contact tick. Exposed neighboring faces provide incidence; shallow
brushes, separation, deep unknown overlaps, airborne/rolled geometry and absent
track/outline do not invent a hard impact. The later same-wall canonical cue is
deduplicated. Physics still supplies its ordinary actual collision response and
all handling/recoil/scrape, input logs, timing, track identities and records remain
exact. No predicted future collision is played. Dynamic loose props retain their
canonical observer path; this visual observer covers mapped solid geometry.

The Game callback arms feedback only after its live pause/countdown/rewind gates,
then resolves sound immediately after the canonical step and before visual UI
work. First live ticks no longer depend on the preceding render's silent latch;
the selected voice explicitly unpauses before play. Standalone/silent/reset
guards remain. Tiny-contact/cooldown gates still apply.

The three impact WAVs start at their **strongest first PCM sample** (each -27524,
peak27524), with no leading zero frame, pre-roll or 3 ms fade-in. They are the only
changed masters: **43** other hashes, including the accepted softer desert bed,
remain exact. Bank revision `collision-direct-6` has 46 clips/10,266,428 WAV bytes,
1,054 fewer than task start. No new external source/API/native dependency.

`Impacts` uses the existing built-in limiter without lookahead at **-2 dBFS**,
unity makeup (`threshold==ceiling`), then the retained -1 dBFS Master hard limiter.
This skips the normal Vehicle dynamics/lookahead for impacts; other vehicle and
music routing remains. `vehicle_volume` and Vehicle mute control both paths.
The existing 22 voice bound and peak protection are retained.

## Actual evidence

[Listen and view the wall comparison](evidence/collision-attack-2026-10-08/audition.html).
The real Game physics callback, with rendering deliberately disabled, now starts
sound on **tick62**, matching visible contact; physical response stays **tick81**
and does not produce a duplicate. All 25 forward cases (five cars x five speeds)
show zero physics-tick gap from mesh contact. Twenty-five rotated approaches and
backing-away/deep-overlap guards also pass. Exact plain/mixed canonical snapshots
are compared in the wall tests; no physical invariant is weakened.

Six real desktop PCM captures (light/medium/hard x two) show the meaningful attack
reaches half its peak within **one 48 kHz sample (0.02083 ms)** of onset. Raw-to-final
path adds **2.0417 ms**, the retained master protection. The WASAPI driver reports
about 10 ms output latency separately. These are digital timing measurements,
not a speaker/Bluetooth/microphone measurement or a zero-acoustic-latency claim.
No visible product UI/geometry change; audio and recorded contact ticks provide
the presentation evidence.

## Commands and outcomes

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1` and `4.7.2.stable.official.ed1daf0bf`.

| Command / suffix | Actual result |
| --- | --- |
| `python scripts/build_vehicle_audio.py` | 46 clips; three impact derivatives change; 43 other hashes exact; maximum asset peak -1.514 dBFS. |
| `Import` | Exit0 with the new direct bus, clips and visible-contact class. |
| `TestScript -ScriptPath res://tests/probe_wall_audio_gap.gd` | Reproduced compact geometry gap208.33/158.33/125/58.33/25ms at3/4/5/10/25m/s. Initial wrong model-method call and unscaled local-bounds attempt corrected; final values include existing88% scale. |
| `TestScript -ScriptPath res://tests/test_visible_wall_audio.gd` | **167 checks, zero failures**: five cars/speeds, rotated walls, no duplicate cue, no backing/deep guessed hit, exact canonical snapshots and actual Game callback62/62/81. Desktop1491-observation mean47.88us/p9591us; no phone profile. |
| `TestScript -ScriptPath res://tests/test_collision_attack.gd` | **22 checks, zero failures**; first live tick/fresh/pause/countdown readiness, source frame0, direct route, ceiling and volume/mute parity. Initial headless33 ObjectDB shutdown references retained in log; no claim of proven runtime leak/clean shutdown for that fixture. |
| `TestScript -ScriptPath res://tests/capture_collision_attack.gd -Graphical` | **42 checks, zero failures**; six native protected PCM captures, first meaningful-to-strong signal within0.5ms, route delay<3ms and retained final ceiling. |
| `TestScript -ScriptPath res://tests/test_effect_timing.gd` | **43 checks, zero failures**, strengthened with three first-sample/full-transient assertions. |
| `TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1442 checks, zero failures**. |
| `TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | **67 checks, zero failures**; surface/acceleration/lifecycle/exact960-tick equivalence. |
| `TestScript -ScriptPath res://tests/test_continuous_desert_audio.gd` | **28 checks, zero failures**; continuous quieter/slight-tone desert retained. |
| `TestApp` / `TestRewind` | **99 /57 checks, zero failures**. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **382 scripts, zero failures** at this run. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/collision-attack-2026-10-08/loop-continuity.json` | **39 loops, zero failures**. |
| `python scripts/review_collision_attack.py` / `python -m py_compile scripts/build_vehicle_audio.py scripts/review_collision_attack.py` | Exact frame0/changed-hash set,25 geometry cases/six PCM bounds/listening artifact and Python compile pass. |
| `Doctor` | Android device present but **unauthorized**; no device audio test/install. |
| `git diff --check -- DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md licenses/ASSETS.md game/core/game.gd game/soundtrack/audio_world.gd` | Exit0; existing CRLF normalization notices retained. |
| `python docs/evidence/collision-attack-2026-10-08/make_checkpoint.py` | 45 pinned files/38 retained logs; task-only reverse patch check exits0. |

The first wall observer selected internal rectangle edges as normals:44 alignment
failures exposed that defect. `failed-first-wall-observer.json` and actual logs
are retained. Selecting only exposed faces fixed it; no alignment/physics check
was relaxed. Only actual emitted cues mark an episode sounded. Initial patch
header mismatch was corrected against the existing editor-serialized resource;
the resource UID/concurrent work is preserved.

Files: `game/vehicle/vehicle_audio.gd`, new `visible_contact_audio.gd`/UID,
`game/core/game.gd`, `game/default_bus_layout.tres`, `game/soundtrack/audio_world.gd`,
`scripts/build_vehicle_audio.py`, three impact WAVs/manifest/notice, strengthened
`test_effect_timing.gd`, new wall/onset/probe/capture scripts/UIDs and
`scripts/review_collision_attack.py`; this note, prior timing link, status/phase/
provenance and task-only review patch/hash inventory. Canonical simulation and
car geometry are not edited. Restart the updated desktop build; an Android APK
must include these sources before device listening can assess the fix.

Owner real-track/corner/bridge listening, physical output path and phone
performance remain open. No authorized device audio measurement, Android
export/install, full Validate, backend/production deployment or purchase is
performed in this audio task. The accepted physical circle may still visibly
overlap the drawn body before its recoil; this slice aligns sound and preserves
that handling contract. Scoped checkpoint leaves the shared Git index alone.
