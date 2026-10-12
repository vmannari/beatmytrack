# Continuous bridge-fence screech — 2026-10-10

The owner subsequently requests stronger body-metal character. The
[metallic scrape revision](METALLIC_SCRAPE.md) changes only the derivative's
timbre and retains this page's continuous-contact implementation.

Owner follow-up: driving along a bridge fence still produces little noticeable
screech. **SND41**, refining SND40/SND08/SND05 and supporting G01/R01/Q01.
This supersedes the prior bridge scrape trigger/mix acceptance in
[Directional collision audio](DIRECTIONAL_COLLISION_AUDIO.md).

The earlier tests covered inward rubbing and isolated friction playback. They
missed **parallel contact after alignment**: canonical force feedback becomes
zero when the resolver removes inward velocity, and the visible-contact branch
required further inward movement. A real creator-bridge rail fixture reproduces
zero scrape audio at 4/12/24m/s, even with a loud engine playing normally.

`VehicleAudio` now also reads the current track collision layer within **25mm**
of the configured physical body radius. Actual occupied geometry must confirm
contact. Tangential travel along the face sustains rubbing after inward motion
ends. A creator rail's authored direction corrects small along-span components
in its raster contact normal, for presentation only; occupied-cell confirmation
still applies. The extra geometry query runs only when the current observer has
not already queued friction, while moving and grounded. It does not modify the
collision solver, car dimensions, track geometry, physics/rules or snapshots.

The friction mix reaches its motion gain at 4m/s rather than 14m/s, has a bounded
minimum audible rubbing strength, and increases its nominal gain from 0.52 to
0.82. A **60ms** hold bridges missing contact ticks and render frames between
physics steps, followed by the existing fast release. Pause/countdown,
air/rollover, retry/rewind and moving away clear or release the sound. A nearby
pass 12cm clear of the rail, standing still and driving below the deck stay
silent. Direct crash clips, gain/cooldown/routing and all **48 WAV hashes** are
unchanged. No player-facing UI or additional audio player is introduced.

Changed files: `game/vehicle/vehicle_audio.gd`,
`game/tests/test_bridge_scrape_audio.gd`, `scripts/review_bridge_scrape_audio.py`,
this document, the prior collision document, `DEVELOPMENT_STATUS.md` and
`docs/PHASE_0_PLAN.md`.

Actual commands use pinned **4.7.2.stable.official.ed1daf0bf** through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Actual command / suffix | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_bridge_scrape_audio.gd -Graphical -TestArgument '--baseline'` | **609 checks/60 failures**, reproduces all five cars/both sides/forward-reverse/three speeds; nine native baseline recordings. |
| Same bridge fixture without `--baseline`, `-Graphical` | Final **611 checks/zero failures**, nine native mix/engine/friction recordings and actual Game integration. |
| Same bridge fixture without `-Graphical` | **602 checks/zero failures** before the final equivalent-query optimization; actual Game physics/presentation integration remains in the final native fixture. |
| `-Action TestScript -ScriptPath res://tests/test_directional_collision_audio.gd` | Final **231 checks/zero failures**, exact ordinary/deck driving comparisons and collision lifecycle. |
| `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,450 checks/zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_shallow_collisions.gd` | **20,268 checks/zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_contact_escalation_audio.gd` | **65 checks/zero failures**, escalation and duplicate protection retained. |
| `python scripts/review_bridge_scrape_audio.py` | Baseline friction exactly silent; corrected friction **2.668/2.897/2.848dB below engine** at 4/12/24m/s. All 48 WAV hashes exact. Vehicle mix peaks about **0.412–0.415**, paused last 200ms exactly silent. |
| Configured SDK `adb devices -l` | OPD2403 tablet attached; **no phone attached**. |

The actual compact Game callback test takes 48 ticks along the compiled creator
rail: **46 audible ticks**, peak scrape gain **0.402**, stays above the bridge.
The 60-case matrix uses the compiled Knit creator document, selected-car body
radius and both rail sides, unlike the preceding synthetic deck-wall fixture.
It also checks moving away, nearby pass, underpass, stationary, airborne,
rollover, countdown and pause contexts. The native preview holds the real
contact position/movement to compare the full vehicle mix; it is not a completed
race or subjective owner listening approval.

The initial proximity correction still rejected 16 reverse cases because a
raster corner normal projected 0.228–0.419m/s outward from truly parallel motion;
authored rail direction fixes these cases without relaxing departure tests.
The first native capture after adding Game integration included menu music
resumed by Game exit: its vehicle channels were silent on pause, but the full
mix check correctly failed. Final capture runs before that independent Game
exit; the same pause assertion passes. These failed logs are retained, and no
product mute, runtime invariant or existing physics assertion was weakened.
Existing contact/shallow tests still emit ObjectDB cleanup warnings at exit.

Evidence: `docs/evidence/bridge-screech-2026-10-10/` contains runtime baseline,
60-case before/after matrices, actual logs, 18 native WAVs, mix report and a
task-only Git-format checkpoint plus hashes. Listen to the full vehicle mix
[before](evidence/bridge-screech-2026-10-10/before-12-mix.wav) and
[after](evidence/bridge-screech-2026-10-10/after-12-mix.wav).

No Android export/install, phone/tablet listening, full Validate, backend work,
deployment, handling/camera change or score write was performed. Restart the
local game to hear the correction; the installed Android build is unchanged.
The owner's exact track/car was not supplied during this turn. Remaining
acceptance is hearing the fix on that client/track and checking tablet/mobile
balance and the bounded proximity query's cost during actual driving.
