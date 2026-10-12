# Engine/grass mix repair — 2026-10-11

Owner reports broken sounds, rough engine artefacts and improper grass feedback
after SND54. **SND55**, refining SND54/SND47/SND09 with G01/R01/Q01/V06 sound
presentation and lifecycle separation.

Two issues are addressed. The previous synthetic grass/gravel layers injected
105–155Hz body notes and substantial low rolling energy into the engine range.
Separately, the shared Vehicle compressor detected the combined engine/tyre
mix, so loud ground peaks **modulated the engine's gain**. A native controlled
probe reproduces this with a steady40Hz engine reference and varying850Hz tyre
energy: engine gain falls to **60.5–89.0%** of its clear-road level despite a
constant engine source. This demonstrates a mixer mechanism, not proof that
every artefact reported by the owner has that single cause.

`default_bus_layout.tres` now gives the existing Vehicle compressor an
**Engine sidechain**. It follows engine energy instead of tyre energy; all bus
names/routes, SFX controls, compressor settings and Vehicle/Master output ceilings
are retained. The same native probe now holds the engine at approximately
**99.5–100.5%**, within1% of its original level. No new production bus, voice or
DSP effect is added. The accepted kerb sample is unchanged; compression response
now follows the engine for all sounds sharing Vehicle.

Grass/gravel now use the previously cleared **Nox grass-driving CC0 recording**
and **cognito perceptu gravel-driving CC0 recording**, instead of generated
body notes/noise clouds. Preserve actual tyre/rustle envelopes and phase, use
overlapped spectral attenuation of narrow motor harmonics, softer260–1900Hz
grass/180–2600Hz gravel EQ and lower level. This is attenuation of tonal content,
not perfect separation of every field-recording component. Grass energy below
220Hz falls **43.46%→0.0686%**, gravel39.55%→4.90%. No synthesized ground tones
remain. Current loops5.25s/12s, combined1,521,534 bytes,16-bit mono44.1kHz;
source/derivative hashes and mastering revision are in the manifest/NOTICE.

All **47 other WAVs**, including all **30 engine clips**, accepted kerb thuds,
owner crashes, Pól rail scrape and desert layers, remain hash-exact. Runtime
audio model, grass contact/120Hz response, wheel materials, canonical physics,
handling/geometry/rules/inputs are unchanged. Bank49/race23 bounded players remain.

Diagnostics now record engine and ground separately through the final routing.
Offroad speed auditions ramp gradually rather than jumping5→18→36m/s in single
frames, which previously caused artificial RPM jumps in the audition. Existing
engine fixtures were too short to exercise the current8s high banks at slow
playback pitch. Keep their **two-or-more-wrap assertions** and give them real
coverage:24s per car at high steady revs, and37s Compact acceleration/coast/rev/
sustained-loop/pause. Production playback is not changed to satisfy a test.

Changed files: `game/default_bus_layout.tres`,
`scripts/offroad_audio_mastering.py`, `build_vehicle_audio.py`,
`surface_audio_mastering.py`, `review_engine_grass_repair.py`,
`game/tests/capture_compact_audio.gd`, `test_vehicle_audio_continuity.gd`,
`test_grass_kerb_audio.gd`, `probe_engine_surface_duck.gd`/UID,
`game/assets/audio/vehicles/grass.wav`, `loose.wav`, `manifest.json`, `NOTICE.txt`,
this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands/results, through pinned4.7.2.stable.official.ed1daf0bf:

| Command | Outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --offroad-only` | Two clips/1,521,534 bytes; repeat all49 WAV hashes exact. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` | Both imports exit0; repaired assets/mixer/diagnostics imported. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/capture_compact_audio.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/engine-grass-repair-2026-10-11/before-engine'` | Original19s fixture **two coverage failures**: high loaded/coasting banks only wrap once. Valid native before recordings retained; source engine discontinuity/dropout audit passes. It does not reproduce an isolated-engine artefact. |
| Same capture with `after-engine` evidence folder after extending the fixture | **Zero failures**,37s recording, wraps20/8/4 for load and coast banks. Includes idle/acceleration/cruise/coast/revs/high hold/pause. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio_continuity.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/engine-grass-repair-2026-10-11/engine-continuity'` | **48 checks/zero failures**, all five cars/high banks wrap twice; stable engine sections have no dropouts or isolated sample-step spikes. These isolated engine-bus captures precede the downstream sidechain edit; engine sources/loop logic are unchanged. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/probe_engine_surface_duck.gd -Graphical` and then `-TestArgument '--after'` | Both native probes exit0; regression audit reproduces40% engine ducking before and verifies within1% afterward. Final after probe also asserts the production Engine sidechain. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,454 checks/zero failures**, repeated after final mixer change. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | **67 checks/zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -TestArgument '--offroad-review=res://../docs/evidence/engine-grass-repair-2026-10-11'` | Final **96 checks/zero failures**,30 mixed/isolated captures; prompt grass/partial/creator fringe/all cars/silence gates/canonical isolation/Game kerbs. Final EngineReview feeds Engine so the production sidechain stays active. Earlier captures were repeated after mixer/routing changes. |
| Same launcher, `-Action TestApp` | **99 checks/zero failures**, after mixer edit, isolated app/records/race smoke flow. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/engine-grass-repair-2026-10-11/loop-continuity.json` | **42 loops/zero failures**, preserved joins/embedded-gap assertions. |
| `python scripts/review_engine_grass_repair.py` | **Seven engine captures/30 mixed-isolated captures pass**: preserved47 assets, source licenses, removal of low ground tones, engine continuity/step outliers, compressor regression, prompt onset/headroom/silent tails. |
| `python -m py_compile scripts/offroad_audio_mastering.py scripts/build_vehicle_audio.py scripts/surface_audio_mastering.py scripts/review_engine_grass_repair.py` | Exit0. |

Engine steady-section minimum20ms RMS0.066–0.068, median0.068–0.069; no dropout
windows. Maximum sample-step/99.99th-percentile ratios1.07–1.38, within the3.5
spike bound. Final grass-entry/grass-ramp/gravel-ramp peaks approximately
0.369/0.504/0.292; final150ms pause tails all exactly silent. Grass still reaches
86.5% of settled gain on the first60FPS contact. First baseline capture warned
of leaked test objects at exit; final longer capture has no such warning. The
first mixer probe warned of four queued objects; flushing after freeing players
removes that warning in the final probe.

Evidence: `docs/evidence/engine-grass-repair-2026-10-11/`, native before/after
compressor probes, seven isolated engine recordings plus tarmac mixes, thirty
surface/mix/engine auditions, hash/continuity/spectrum/contact/regression reports,
actual logs, scoped Git-format patch and checkpoint hashes. Shared index/unrelated
work untouched. The previous direct-hit collision regression remains unchanged;
no full-suite-green claim. No backend/UI/physics change or deployment.

Remaining acceptance: restart an already-running game to load the revised mixer,
then owner listening during real road/grass transitions and on the selected
vehicle. The exact reported clean-tarmac/grass context was requested but not
provided during this turn. **No phone listening/device test, Android export or
installation performed.** Desktop captures do not prove physical-device audio
driver timing, absence of every audible artefact or subjective grass quality.
