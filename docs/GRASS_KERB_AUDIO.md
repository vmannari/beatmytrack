# Prompt grass entry and kerb feedback — 2026-10-11

Owner request: grass sounds arrive after the car is already well onto grass;
crossing and riding kerbs need appropriate feedback. **SND47**, refining
SND09/SND05 and supporting G01/R01/Q01/V06. This is sound presentation only.

Grass now responds on the actual post-simulation wheel contact before rendering.
The four selected-car wheel locations are retained; no future-position prediction
is used. Partial grass contact is emphasized with a square-root material mix,
the rustle is stronger against the engine, and its response changes from14/s
to120/s. At60FPS the first displayed contact reaches **86.5%** of settled level
instead of **20.8%** (gain0.484 vs0.082 at18m/s). Returning to road, countdown,
air/rollover and pause clear the grass channel immediately.

Original creator pine/storm tracks have a metre-wide raster shoulder marked5,
previously treated entirely as pavement even across the rendered grass fringe.
Non-raised portions now receive a conservative half-grass/half-rolling audio
blend. This is a presentation blend, not exact reproduction of per-pixel shader
grass or a change to canonical soil forces. Real raised kerb geometry overrides
grass and uses concrete rolling feedback; legacy native kerb cells, painted
materials, desert sand and elevated layers retain their material contracts.
The actual compiled creator-curve fixture measures grass fraction0.500→0.625
at a real fringe contact while preserving the underlying grid and kerb geometry.

Crossing a kerb starts the existing low chassis bump **directly after the physics
step**, based on real prepared kerb heights. Previous/current contact or canonical
heave enables a bounded sweep: at most8 intermediate poses, four wheel points
each, with the current endpoint reused. This catches thin/fast crossings between
render frames without turning a kerb into a crash. Entry cooldown80ms groups
rapid same-contact taps; contact history prevents repeated bumps while riding.

A new `kerb_roll.wav` supplies continuous tyre/body rumble while wheels remain
on a raised kerb. Speed drives intensity/pitch; a40ms presentation hold bridges
render/physics gaps. Stationary, airborne, rollover, countdown, pause and bridge
deck cases remain silent. The faint render-time heave-threshold kerb tap is
removed to avoid duplicate/repeated suspension cues. Landing/downshift and
collision sounds retain their existing separate behavior.

The loop uses already cleared CC0 cognito perceptu gravel-driving rumble and
Nox body foley, authored offline with no new source download or dependency.
This is designed kerb feedback, not a claimed dedicated curb field recording.
All **48 prior WAV hashes** are exact, including grass, owner-selected crash and
Pól rail scrape. The bank now has **49 clips**, adding one **5.5s/485,144-byte**
mono44.1kHz/16-bit loop. The race has **23 bounded players**: the previous22 plus
one kerb loop. Four body and two debris slots remain exact; the kerb crossing
uses existing chassis/native body slots, not another one-shot pool.

Changed files: `game/vehicle/vehicle_audio.gd`, `surface_audio_model.gd`,
`game/core/game.gd` (one post-step observer call adds previous pose),
`scripts/kerb_audio_mastering.py`, `build_vehicle_audio.py`,
`surface_audio_mastering.py`, `review_grass_kerb_audio.py`,
`game/assets/audio/vehicles/kerb_roll.wav` and import/manifest/NOTICE,
`game/tests/test_grass_kerb_audio.gd`/UID and existing audio fixtures' declared
bank/voice budgets, `test_direct_hit_body_audio.gd` diagnostic fields/bypass
option, this document, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.
No `VehicleSimulation`, handling config, track compiler/geometry, rules or
backend file changes. Collision outline sampling and acceptance logic are exact
to the task-start versions.

Actual commands use pinned **4.7.2.stable.official.ed1daf0bf** through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Actual command / suffix | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -TestArgument '--baseline'` | **16 checks/11 failures**, reproduces delayed/quiet grass across all five cars and absent kerb rumble. First fixture parse failed on the not-yet-supported optional observer arguments; dynamic diagnostic calls corrected it. |
| `python scripts/build_vehicle_audio.py --kerbs-only` | One loop/485,144 bytes; scoped and ordinary full bank paths share the renderer. Repeat all49 WAV hashes exact. Scoped kerb rebuild does not require owner crash/rail source archives. |
| `-Action Import` | **Exit0**, new resource/scripts imported. |
| `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical` | Final **75 checks/zero failures**, first physics/render grass, partial contact, actual creator fringe, all five cars, kerb riding, stationary/air/roll/deck/pause/countdown, actual canonical fast crossings/snapshot equivalence and Game integration. Nine native recordings. |
| Same focused fixture without `-Graphical` before the final added contact/Game cases | **60 checks/zero failures**. Final added cases are verified in the75-check native run. |
| `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | Final **1,454 checks/zero failures**, new49-clip bank, bounded23-player budget and lifecycle/canonical separation. |
| `-Action TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | **67 checks/zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_continuous_desert_audio.gd` / `test_desert_audio.gd` | **28/25 checks, zero failures**; no unwanted recurring sand impacts or grass/road overlays. |
| `-Action TestScript -ScriptPath res://tests/test_wet_road_audio.gd` | **41 checks/zero failures**, deferred wet rolling remains unchanged. |
| `-Action TestScript -ScriptPath res://tests/test_kerbs.gd` | **31 checks/zero failures**, unchanged physical crossings/reverse/speed loss/settling/layer behavior. |
| `-Action TestScript -ScriptPath res://tests/test_directional_collision_audio.gd` | **231 checks/zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_bridge_scrape_audio.gd` | **602 checks/zero failures**, accepted rail scraping retained. |
| `-Action TestApp` | **99 checks/zero failures**, isolated app/race/records smoke flow. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/grass-kerb-audio-2026-10-11/loop-continuity.json` | **42 loops/zero failures**, three repetitions/joins/no embedded gaps. |
| `python scripts/review_grass_kerb_audio.py` | First-frame response, isolated native contact onsets/headroom/pause tails and all48 prior WAVs pass. |
| `python -m py_compile scripts/kerb_audio_mastering.py scripts/review_grass_kerb_audio.py scripts/build_vehicle_audio.py scripts/surface_audio_mastering.py` | Exit0. |
| Configured SDK `adb devices -l` | **DN2103 phone attached**; listening/install/performance test not performed. |

The actual Game crossing produces **two axle/contact bumps**, rumble peak
**0.401**, and **zero collisions** with coarse rendering. Fixed-input crossings
at8/20/40m/s preserve every compared driving snapshot. Native mix peaks are
0.362/0.250/0.276 for grass-entry/kerb-cross/kerb-ride; all last150ms exactly
silent on pause. Observed live grass contact0.708s vs recorded onset0.693s
agrees within15ms; recorder and CPU clocks have different block origins, so
this is not a negative physical latency or sound-before-contact claim.
Kerb recorded onsets follow contact timestamps by about7ms/3ms.

The first focused run falsely counted a later legitimate wall crash as another
kerb bump:63 checks/one failure. It now compares the kerb-specific event counter
while retaining the assertion that no additional kerb bumps occur after leaving.
No runtime threshold or physical invariant was weakened.

**Known existing collision regression:** `test_direct_hit_body_audio.gd` reports
**5 checks/one failure** because the current45° fixture emits a primary physical
hit at tick21 and a secondary physical hit at tick50. The same two events occur
with `--without-surface-observer`, proving the new surface observer is not their
cause. The original single-primary-hit assertion remains unchanged; this is not
an all-suite-green claim. Diagnostics record physical impulse/touch/outline data.
A trial of full-hull probes and preserving accepted contact state did not remove
the failure and was reverted; collision outline code is restored exactly and no
collision suppression/tuning change ships in this slice. Further collision-case
review remains separate acceptance work.

Evidence: `docs/evidence/grass-kerb-audio-2026-10-11/` holds frozen runtime and
source baselines, before/after onset matrices, actual pass/fail logs, native
timing/PCM review, nine WAVs and a task-only Git-format binary/source checkpoint
with SHA-256 ledger. Listen to [grass entry](evidence/grass-kerb-audio-2026-10-11/grass-entry.wav),
[kerb crossing](evidence/grass-kerb-audio-2026-10-11/kerb-cross.wav) and
[kerb riding](evidence/grass-kerb-audio-2026-10-11/kerb-ride.wav).
These are controlled real-engine/mixer excerpts and a separate actual Game
integration check, not completed player races or subjective device acceptance.

No visible UI change, phone listening/performance, Android export/install,
full Validate, physics/rules/camera change, backend work, deployment or live
score/player-file writes were performed. Restart the local game; installed
Android remains unchanged. Owner listening on the affected track and phone,
including additional surface-query cost during actual driving, remains.
