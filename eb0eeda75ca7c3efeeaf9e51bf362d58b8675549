# UFO-inspired hovercraft control, with tighter recovery

Owner request: the previous hovercraft is not fun; try the UFO feeling from Slicks ’n’ Slide. During implementation the owner reports that the freely drifting candidate is not controllable. The final `hovercraft-4` responds to both instructions.

## Reference and limits

The [author’s official downloads](https://slicksnslide.com/?pr=dos-slix&showold=1) provide the public `slix129d.zip` archive. Its English `SLICKS.L02` vehicle entry describes the UFO as slow, fast-turning and light. The public documentation does not supply its movement equations. The implementation here is an original interpretation of the requested feel, not a measured or exact port. Archives were downloaded into ignored `build/hovercraft-ufo-reference/` and inspected as data; no original executable ran or original code/artwork shipped. `reference.json` retains URLs and archive hashes.

## Resulting behavior

- HUF01: heading is independent of speed, throttle and drift direction. The hull can turn while stationary, and sliding backwards never reverses steering.
- HUF02: fan thrust acts in the direction the hull points. Coasting retains world momentum, with direction-independent drag. Turning alone cannot change the travel vector or create energy. The air cushion ignores tire/ground-material grip; existing physical obstacles, jumps and bridge contacts remain.
- HUF03: after the owner rejects the very loose `hovercraft-3` candidate, `hovercraft-4` lowers the turning cap from 3.4 to 2.6 rad/s, shortens angular response/steering release and raises coasting damping from 0.18 to 0.35. Powered lateral damping of 1.8 catches a slide progressively while applying throttle. It dissipates sideways energy instead of snapping velocity onto the hull or converting drift into speed. Brake opposes the complete movement vector; the stopped reverse delay, reverse cap, simultaneous-pedal priority and 130 km/h forward cap remain.
- HUF04/R01: `vector_thrust` and optional powered recovery are explicit versioned capabilities, omitted from unchanged configuration snapshots. The old hovercraft movement branch remains. Actual task-start simulation runs match every tick for the five current other cars and historical hovercraft-1/2: 16,800 exact state comparisons through collisions.

Runtime scope is three files: `game/resources/cars/hovercraft.tres`, `game/vehicle/handling_config.gd` and `game/vehicle/vehicle_simulation.gd`. No model, camera, input mapping, art or audio change is required. The historical power/turn regression now loads the retained hovercraft-2 fixture; its current-native identity assertion is covered for hovercraft-4 by the new suite. New behavior/native tests and retained source/resource fixtures accompany the change.

## Actual validation

All Godot commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned `4.7.2.stable.official.ed1daf0bf`, isolated workspace APPDATA and an empty `BMT_API_URL`.

| Command/check | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_hovercraft_ufo.gd` | 92 checks, zero failures: control direction, stationary turning, momentum, powered recovery, braking/reverse, 48 five-second turn/power cases, exact legacy states, serialized replay and rewind |
| `res://tests/test_hovercraft_power_turn.gd` | All 127 original hovercraft-1/2 comparison checks pass with the historical tune pinned |
| `res://tests/generate_hovercraft_replay.gd --output=res://../docs/evidence/hovercraft-ufo-feel-2026-10-28/five-lap-replay.json` | Five laps, 28,346 elapsed ticks, zero contacts |
| Independent staged native backend | Normal trajectory acceptance and canonical simulation agree: 28,346 ticks / 236,217 ms; hovercraft-4 identity |
| `res://tests/capture_hovercraft_ufo_drive.gd -Graphical -RenderingMethod gl_compatibility` | 14 checks, zero failures; actual Game loads the tune and presents coast-turn, power-catch, correction and air-brake phases without changing canonical state; four captures inspected |
| `res://tests/test_script_parse.gd` | 1,402 scripts, zero failures |

The final right-angle hull turn takes 0.675 s at rest and during forward, lateral or backward drift. A 20 m/s coast retains 13.5339 m/s after one second. For the same initial 15 m/s sideways slide, 0.75 s of coasting retains 11.2442 m/s sideways; throttle reduces it to 2.9200 m/s. Steering-release overshoot is 10.5340 degrees. A diagonal `(15,20)` m/s brake fixture stops in 1.55 s. These quantify the control changes; they do not establish that the owner finds the result fun.

The raw hovercraft-3 candidate passed its initial 90 stability/behavior checks but was rejected by the owner as uncontrollable. Its resource and report remain as `rejected-hovercraft-3*`. One initial final-tune assertion retained the rejected candidate’s excessive drift floor; it failed at 3.17395 m/s of remaining original travel. The assertion now checks the accepted recovery requirement while still requiring progressive momentum lag. The initial native fixture lacked its synthetic save directory and emitted warnings; the directory is explicitly created and the final 14-check run is clean. Cold presentation produced a recorded 238 ms hitch; no performance claim is made from these captures or their fast-forwarded FPS display.

## Delivery and acceptance

Evidence, source hashes, exact results and source-only `task.patch`: `docs/evidence/hovercraft-ufo-feel-2026-10-28/`. Earlier evidence remains intact. Concurrent Electric/input/Garage/backend work and generated build metadata are preserved; no unrelated source hunk is owned by the checkpoint.

Reload/rebuild the client to try this tune. Owner feel acceptance remains, especially after the mid-task controllability correction. The live backend/current track contracts need an authorized matching rollout; none was performed. No physical-device query/test, APK/export/install, real authentication/purchase, owner-save/live write, owner-process restart or Git staging/commit/merge occurred.
