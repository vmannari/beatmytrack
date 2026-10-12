# Directional collision audio — 2026-10-10

Owner request: improve collisions so fence/bridge side scrapes screech, while
head-on hits crash more strongly. **SND40**, refining SND08/SND04-SND06 and
supporting G01/R01/Q01/V06. This is a local sound presentation change.

`VehicleAudio.resolved_contact` observes incoming movement and the existing
canonical scrape normal, or a current visible solid-contact normal. Closing
incidence controls the balance between crash and sliding friction; an impulse
normal supplies an approximation when no geometric normal is available.
This fallback can contain tangential drag, so it does not identify every contact
face exactly. Glancing hits have reduced crash gain/severity and more screech;
direct hits retain the heavy attack. Sliding speed and rubbing strength control
the sustained friction gain/pitch. Reverse uses actual movement, not heading.

The scrape voice now plays a dedicated six-second screech rather than quietly
reusing gravel. Light brushes at high speed are audible; stationary pressure
cannot squeal. Ground and elevated deck contacts use the same observer. A
32/s envelope follows contact and releases quickly when it ends. Physics can
queue friction on the first live tick without waiting for an earlier rendered
frame. Existing cooldown/duplicate-contact protection, pause/countdown,
air/rollover, retry/rewind clearing and Vehicle volume gates remain.

Medium and heavy impact derivatives have deeper body layers and longer settling
tails. All three retain their full transient in the first PCM frame. Strong
head-on playback gain is now 0.98 instead of 0.90 before retained output ceilings.
The **22-player** budget is unchanged. Windows body events still use the
existing fast output adapter; the other platforms retain ordinary Godot buses.

Changed files:

- `game/vehicle/vehicle_audio.gd`: contact-angle mix and dedicated friction voice.
- `scripts/collision_audio_mastering.py`: offline scrape/crash authoring.
- `scripts/build_vehicle_audio.py`: `--collisions-only` scoped rebuild and bank metadata.
- `scripts/surface_audio_mastering.py`: delegates collision authoring to the same renderer during complete bank rebuilds; suspension foley remains separate.
- `game/assets/audio/vehicles/{scrape.wav,impact_0.wav,impact_1.wav,impact_2.wav}` and their import metadata, `manifest.json`, `NOTICE.txt`.
- `game/tests/test_directional_collision_audio.gd`, `game/tests/test_vehicle_audio.gd`, `scripts/review_directional_collision_audio.py`.
- This document, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

The bank has **48 clips**. Only the three prior impact WAVs change; all **44 other
existing WAV hashes** are exact. The new scrape and three impacts occupy
**549,148 bytes** together. No handling/rules/physics/input/competitive snapshot,
backend, save or camera file changes are part of this task.

The new friction recording combines the bank's already cleared audible-edge
(Tom Haigh)/qubodup tire squeal (CC BY 3.0), KALeigh0218 stone/metal contacts and
cognito perceptu gravel driving (CC0). The crash sources remain qubodup's CC0
designed mechanical collision and Nox CC0 body movement. Offline filtering,
transposition, dense recorded grains, cyclic joins, envelope mastering and
dither are documented in shipping NOTICE/manifest. These are authored effects,
not dedicated real fence, bridge or crash field recordings. No new recording,
download, purchased source, runtime API, synthesis or dependency was introduced.

Actual commands use pinned **4.7.2.stable.official.ed1daf0bf** through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Actual command / suffix | Outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --collisions-only` | Four clips, 549,148 bytes. |
| `-Action Import` | Exit 0 outside sandbox; original sandbox attempt failed reading Windows certificate store/access denied. |
| `-Action TestScript -ScriptPath res://tests/test_directional_collision_audio.gd -Graphical` | Final **243 checks, zero failures**, four native desktop PCM captures. |
| Same directional fixture without `-Graphical` | **231 checks, zero failures**, including 900 actual native fence/deck simulation ticks and exact comparison against an unobserved simulation. |
| `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | Final **1,450 checks, zero failures**, bank hashes, lifecycle and exact simulation equivalence. |
| `-Action TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | **67 checks, zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_collision_attack.gd` | **22 checks, zero failures**; immediate PCM attacks/output routing retained. |
| `-Action TestScript -ScriptPath res://tests/test_contact_escalation_audio.gd` | Final **65 checks, zero failures**; soft-contact escalation and canonical/visual deduplication. |
| `-Action TestScript -ScriptPath res://tests/test_direct_hit_body_audio.gd` | Final **5 checks, zero failures** through actual Game physics/presentation callbacks. |
| `-Action TestScript -ScriptPath res://tests/test_shallow_collisions.gd` | **20,268 checks, zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_windows_impact_audio.gd -Graphical` | **18 checks, zero failures**, real Windows RAW adapter and four bounded body voices. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/directional-collision-audio-2026-10-10/loop-continuity.json` | **41 loops, zero failures**, three repetitions/no embedded gap or bad wrap. |
| `python scripts/review_directional_collision_audio.py` | Four audible, unclipped captures; last 200ms exactly silent. Three changed/44 unchanged prior WAVs and every manifest SHA-256 verified. |
| `python -m py_compile scripts/collision_audio_mastering.py scripts/build_vehicle_audio.py scripts/surface_audio_mastering.py` | Exit 0. |
| Configured SDK `adb devices -l` | OPD2403 tablet attached; **no phone attached**. |

The first directional fixture incorrectly demanded an impact from 3m/s contacts
whose canonical observer impulse is below the preserved 1.2 threshold: 213
checks/10 failures. It now checks that actual existing threshold explicitly.
The first actual-wall fixture wrongly demanded loud sound on its final tick,
even when the pickup had already stopped rubbing: 243 checks/2 failures.
Retained trace proves 39 rubbing ticks and peak gain 0.088; the corrected check
requires more than 30 rubbing ticks and audible gain **during** the contact.
No runtime threshold, physics assertion or existing regression was weakened.
Some existing headless tests emitted ObjectDB cleanup warnings; completed test
results above are not a whole-project resource-leak or full Validate claim.

Evidence is under `docs/evidence/directional-collision-audio-2026-10-10/`:
source/impact baselines, contact matrix, copied actual logs, PCM/continuity
reports, scoped Git-format source/binary patch and SHA-256 ledger. Shared dirty
index and unrelated concurrent work are preserved.

Listen to the [fence scrape](evidence/directional-collision-audio-2026-10-10/fence-scrape.wav),
[bridge scrape](evidence/directional-collision-audio-2026-10-10/bridge-scrape.wav),
[oblique hit](evidence/directional-collision-audio-2026-10-10/oblique-impact.wav)
and [head-on crash](evidence/directional-collision-audio-2026-10-10/head-on-crash.wav).
These three-second previews isolate contact audio using the actual Godot fallback
buses/ceilings. They are designed resolved-contact excerpts, not full player
drives; the actual ground/deck simulations are checked separately. Windows RAW
playback is tested separately and is not captured by Godot bus recording.
Final preview peaks are approximately 0.223/0.226/0.599/0.794 respectively.

No visible UI change, phone/tablet listening test, Android export/install,
full Validate, backend operation or production deployment was performed.
Restart the local game to load the update; the installed Android build is
unchanged. Remaining acceptance is owner listening during real scrapes/direct
hits and a device test of balance against the engine, particularly at different
speeds and on creator fence/bridge geometry.
