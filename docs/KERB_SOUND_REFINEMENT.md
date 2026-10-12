# Recorded kerb rumble — 2026-10-11

Owner request: driving on kerbs still sounds wrong. **SND50**, refining SND47,
with G01/R01/Q01/V06 presentation and lifecycle separation. Kerb detection,
grass onset, canonical handling, track geometry and driving inputs are unchanged.

The rejected loop mixed gravel noise with a dense sequence of repeated body
knocks. Its speed/14 pitch range0.25–2.5 also stretched slow contact into knocks
and raised fast contact into a buzz. The replacement uses only recorded tyre
vibration from **TRANSPORTATION CAR PASS BY 01.wav**, by sengjinn, CC0:
https://freesound.org/people/sengjinn/sounds/176215/
The author describes a car passing over rumble strips/sleeper lines. This is a
kerb derivative of that recording, not a claimed circuit-kerb field recording.

Public HQ preview decoded by pinned Godot4.7.2.stable.official.ed1daf0bf:
307,008 encoded bytes;588,589 mono float frames at44.1kHz. The close pass
6.6–9.4s is filtered80–1750Hz with low-mid emphasis, cyclic power crossfaded,
envelope/loudness mastered and dithered to16-bit PCM. No gravel, synthetic
pulses or repeated body-knock train remains in the loop. Result **2.333s,
205,844 bytes**;99.77% of spectral energy lies80–1750Hz at native pitch.
The runtime pitch follows sqrt(speed/18), bounded0.65–1.35, retaining tyre/body
colour at low and high speeds. The real entry chassis bump is quieter and
lower: gain0.10–0.24 instead of0.16–0.38, pitch0.78 instead of0.90. Continuous
contact, intensity,40ms hold, contact sweep and immediate silence gates remain.

Changed files: `scripts/kerb_audio_mastering.py`, `build_vehicle_audio.py`,
`prepare_kerb_rumble_source.py`, `review_kerb_refinement.py`,
`game/vehicle/vehicle_audio.gd`, `game/tests/decode_kerb_rumble.gd`/UID,
`test_grass_kerb_audio.gd` (evidence-directory argument and three-speed audition),
`game/assets/audio/vehicles/kerb_roll.wav`, `manifest.json`, `NOTICE.txt`,
this document, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.
All **48 other bank WAVs** remain exact, including the owner-selected crash,
Pól rail scrape and grass. Bank49 clips/race23 bounded players are unchanged.
Source license page/MP3/float WAV/source manifest stay in non-exported build
inputs; exact encoded/decoded/derivative SHA256 and decoder are in the bank
manifest. Both scoped and full mastering paths use the same kerb renderer.

Actual commands and outcomes:

| Command | Outcome |
| --- | --- |
| `Invoke-WebRequest` source page/HQ preview | Initial sandbox page request could not connect; approved request succeeded. Public CC0 page retained and307,008-byte preview downloaded; TLS verification retained. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/decode_kerb_rumble.gd` | Exit0;588,589 frames at44.1kHz. |
| `python scripts/prepare_kerb_rumble_source.py` | Exit0; license validated, checksums/source manifest and float WAV prepared. |
| `python scripts/build_vehicle_audio.py --kerbs-only` | One205,844-byte loop; repeat rebuild all49 WAV hashes exact. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` | Exit0; new scripts and revised kerb imported. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,454 checks/zero failures**; bank/budget/lifecycle/canonical separation. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/kerb-refinement-2026-10-11'` | First75/final**78 checks/zero failures**; all five cars, immediate/partial grass, actual creator fringe, kerb crossings/riding, air/roll/deck/stationary/countdown/pause, fixed-input snapshot equivalence and actual Game callback. Final adds5/18/36m/s controlled-wheel-contact native mix audition. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/kerb-refinement-2026-10-11/loop-continuity.json` | **42 loops/zero failures**, repeated wraps/no embedded gaps. |
| `python scripts/review_kerb_refinement.py` | **12 native captures**, headroom/pause tails/kerb audibility/no false kerb on grass, low-mid spectrum, accepted48 WAVs exact. |
| `python -m py_compile scripts/kerb_audio_mastering.py scripts/prepare_kerb_rumble_source.py scripts/build_vehicle_audio.py scripts/review_kerb_refinement.py` | Exit0. |
| Configured Android SDK `adb devices -l` | Initial sandbox request failed creating the Android user cache; approved read-only retry succeeded: **DN2103 attached**. No installation or phone listening performed. |

Actual Game fixture: two axle/contact bumps, rumble gain peak0.401, zero
collisions. Native crossing/ride/three-speed mixed peaks0.268/0.258/0.313;
every final150ms pause tail is exactly silent. Auditions are controlled
presentation poses, not complete races or a physical mobile performance test.
An optional spectrum plot failed because matplotlib is not installed; numerical
FFT analysis and spectral audit succeeded without adding a dependency.

Evidence: `docs/evidence/kerb-refinement-2026-10-11/`, including twelve WAVs,
contact timing, spectrum/headroom/hash reports, source metadata, actual logs,
task-only Git-format patch and checkpoint hash ledger. No staged/index changes
or unrelated shared-workspace changes are included in that checkpoint.

Remaining acceptance: owner listening during actual kerb riding/crossing,
especially through phone speakers/headphones; DN2103 is attached. **No phone listening/device test,
Android export/install, backend change or deployment performed.** Existing
45-degree direct-hit collision fixture regression remains documented in
`GRASS_KERB_AUDIO.md`; its collision logic/assertions were not changed here.
No whole-suite-green claim or physics contract change is made.
