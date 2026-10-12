# Direct collision timing investigation — 2026-10-09

The owner clarifies that the unresolved delay concerns **direct collisions**.
The preceding soft-contact escalation correction does not explain that report.
SND-DC01 therefore measures direct head-on hits under normal rendering and adds
opt-in tracing for the actual reported case. SND05/SND14–SND18/G01/R01/Q01/V06
remain: unchanged canonical simulation, immediate source attack, protected
bounded audio and pause/rewind/volume safeguards.

**The owner's reported direct-hit delay is still unresolved.** No new collision
timing fix or hardware explanation is claimed from these results.

## Actual direct-hit measurements

`probe_direct_collision_output.gd` runs the shipping Game physics callback at
real fixed-frame intervals while its normal `_process` rendering/interpolation
remains active. Neutral input prevents unrelated keyboard input from steering
the controlled fixture. Six direct compact-car head-on hits cover 5/15/30 m/s
(18/54/108 km/h). Three use normal current visible-footprint feedback; three
deliberately disable that early observer to measure canonical collision-only
dispatch as a control. The latter control is not a production behavior change.

Own-process WASAPI capture verifies **all six actually used Windows RAW** and
each produced one cue, without a late duplicate. Thirty review checks pass:

| Speed | Normal: cue to captured output | Normal: rendered footprint to output | Canonical-only: cue to output |
| --- | ---: | ---: | ---: |
| 18 km/h | 39.53 ms | 22.53 ms | 44.53 ms |
| 54 km/h | 36.53 ms | 28.53 ms | 42.53 ms |
| 108 km/h | 44.53 ms | 35.53 ms | 45.53 ms |

Normal cue/rendered-footprint/physical ticks are 73/74/89, 25/25/30 and 13/13/15.
Canonical-only cues match the actual physical response tick exactly. Disabling
early feedback gives 160.53/76.53/54.53 ms from rendered footprint to captured
output in these controls, demonstrating why missing early feedback can resemble
lag. It does not demonstrate that the owner's game has that condition.

This is **software process-loopback**, not a microphone measurement. It includes
capture-path timing, and `frame_post_draw` is not monitor scanout. Footprint
contact is computed from the car transform/hull at completed rendering, rather
than an acoustic or physical monitor recording. Other game sounds are muted in
the controlled fixture so a delayed chassis/music event cannot contaminate onset
detection. The raw packet/event data are retained. No microphone or unrelated
application audio was recorded.

The user's locally saved selection is compact / cloud **Slippery**, read from
only the relevant settings and matching public cached track metadata. This is
not proof that it is the reported current track. A read-only geometry probe
compiles that cached document and approaches all four outer boundaries. All
eight actual hits at 54/108 km/h cue on the first observed touch, remain one cue
through later physical response, and preserve exact plain/observed snapshots.
The four 18 km/h coasting cases stop in snow before reaching the wall and are
**not successful collision cases**. The probe retains a 33-reference shutdown
warning. Its initial Vector2/scalar-expression parse error was corrected and
retained; no physics/geometry requirement was relaxed.

## Actual-case tracing

`VehicleAudio` now recognizes **`--collision-audio-trace` in debug builds only**.
Default play does not emit telemetry. For a visible cue or canonical collision,
the optional deferred log records time/tick, car, track, source, incoming speed,
impulses, whether playback was accepted, actual Windows RAW/Godot/suppressed
route, native ready/error/submission counters, outline/normal, prior presentation
tick/FPS and gain. No account/session/token data or external service is involved.
Logging is deferred until after the physics callback. No diagnostic clock or
file/network access enters `VehicleSimulation.step`; collision behavior is unchanged.

The ordinary development launcher already retains stdout in its own command log.
`run_collision_trace_app.gd` opens the normal app with the title
**CIRCUIT / 01 - Collision timing** and a bounded 120-second session. One actual
launch emitted `APP_READY` and `COLLISION_TRACE_APP_READY pid=8224`. **No collision
trace was received during that session**, which then closed normally. It did not
reproduce or inspect the owner's particular hit. Other running windows were not
closed or controlled. The pending user question requests track, car and obstacle.

To repeat the normal-game trace:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/run_collision_trace_app.gd -Graphical -TestArgument '--collision-audio-trace' -CommandTimeoutSeconds 180
```

Choose the same car/track and make a direct hit in that window. The matching
`build/logs/TestScript-*/test-script.log` contains `COLLISION_AUDIO_TRACE` lines.
This does not start a microphone capture. The earlier live-module check confirms
that current workspace processes loaded v2, but a loaded library alone cannot
prove the route of a particular sound; that is why per-hit route logging is needed.

Other actual commands through pinned **4.7.2.stable.official.ed1daf0bf**:

```powershell
TestScript -ScriptPath res://tests/probe_direct_collision_output.gd -Graphical
TestScript -ScriptPath res://tests/probe_cached_direct_walls.gd -TestArgument '--document=<local cached document>'
TestScript -ScriptPath res://tests/test_collision_trace.gd
TestScript -ScriptPath res://tests/test_effect_timing.gd
TestScript -ScriptPath res://tests/test_windows_impact_audio.gd -Graphical
CheckScript -ScriptPath res://tests/run_collision_trace_app.gd
TestScript -ScriptPath res://tests/test_script_parse.gd
python scripts/review_direct_collision_output.py
```

The process-loopback helper was the existing own-PID-only executable, armed with
the PID in `ready.json` for 25 seconds. Trace **9**, timing **43**, native Windows
**16**, launcher check and parser **414** checks pass. The normal-app session
exits0. No passed test is described as a reproduction of the reported 100 ms
direct-hit symptom. No new native DLL, source clip, volume or driving force change.

Changed files: `game/vehicle/vehicle_audio.gd` (optional tracing),
`game/tests/probe_direct_collision_output.gd`, `probe_cached_direct_walls.gd`,
`run_collision_trace_app.gd`, `test_collision_trace.gd` and their UIDs,
`scripts/review_direct_collision_output.py`, this note, `DEVELOPMENT_STATUS.md`,
`docs/PHASE_0_PLAN.md` and scoped evidence/checkpoint under
`docs/evidence/direct-collision-timing-2026-10-09/`.

No phone attachment check/physical Android audio test, microphone or new acoustic
measurement, export/install, full Validate, canonical/rules change, backend
modification or deployment was performed. Runtime tracing has no game-screen UI;
the title belongs only to the explicit diagnostic launcher. Exact reported
track/car/object, actual-hit trace and connected-speaker/Bluetooth listening
remain necessary to locate the owner's delay. Downstream hardware timing cannot
be inferred from these software-only measurements.
