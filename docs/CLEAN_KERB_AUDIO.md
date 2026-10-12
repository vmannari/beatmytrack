# Clean kerb tyre vibration — 2026-10-11

Owner rejects the rumble-strip field recording because it contains other noise.
**SND51**, refining SND50/SND47 with G01/R01/Q01/V06 audio presentation.
Replace the recording rather than filtering its traffic/engine into the cue.

`kerb_roll.wav` now contains an original offline sound design with **no field
recording**. Deterministically generated excitation drives broad, damped
rubber/body resonances around135/265/490Hz, with a restrained300–1150Hz
rolling texture. A shallow24Hz flutter suggests loading over kerb ridges;
smooth phase and pressure variation avoid a perfectly repeated short beat.
The flutter never closes into silence or schedules separate knocks. Final
70–1400Hz EQ, cyclic power joins, envelope/loudness mastering and16-bit dither
produce a **7.5s/661,544-byte**, mono44.1kHz PCM loop. **99.31%** of spectral
energy is80–1750Hz. This is authored tyre vibration, not a measured physical
kerb recording or new runtime synthesis/dependency. Generator/seed/derivative
hash are recorded in the bank manifest; old source credits are historical.

The existing quieter entry bump,0.65–1.35 speed pitch, wheel detection,
continuous ride mix, swept crossing contact,40ms hold and immediate silence
gates are unchanged. Grass onset and accepted crash/rail-scrape clips retain
their exact behavior/assets. All **48 other bank WAV hashes** are unchanged;
the49-clip bank and23 bounded players are retained. The previous kerb source
archive is no longer required for either scoped or full kerb mastering. Offline
historical decoder/source-preparation files are retained, not used by this cue.

Changed files: `scripts/kerb_audio_mastering.py`, `build_vehicle_audio.py`,
`review_kerb_refinement.py` (selectable evidence folder and revision-specific
source audit), `game/assets/audio/vehicles/kerb_roll.wav`, `manifest.json`,
`NOTICE.txt`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.
No runtime GDScript, simulation, geometry, handling, backend or UI changes.

Actual commands/outcomes:

| Command | Outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --kerbs-only` | One661,544-byte clip; repeat build all49 WAV hashes exact. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` | Exit0; pinned4.7.2.stable.official.ed1daf0bf imports the replacement. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,454 checks/zero failures**, audio bank/voice budget/lifecycle/simulation isolation. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/clean-kerb-audio-2026-10-11'` | **78 checks/zero failures**; all five cars, actual kerb crossings/riding, immediate grass, canonical snapshot equivalence, actual Game callback, silence gates;12 native captures including5/18/36m/s engine mix. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/clean-kerb-audio-2026-10-11/loop-continuity.json` | **42 looped assets/zero failures**, wraps and embedded-gap checks. |
| `python scripts/review_kerb_refinement.py --evidence-dir docs/evidence/clean-kerb-audio-2026-10-11` | **12 captures pass**; no recorded source in kerb metadata, spectral band/headroom/pause tails/audible kerb/no false cue on grass,48 other WAVs exact. |
| `python -m py_compile scripts/kerb_audio_mastering.py scripts/build_vehicle_audio.py scripts/review_kerb_refinement.py` | Exit0. |

Actual Game crossing remains two axle/contact bumps, rumble gain peak0.401 and
zero collisions. Native crossing/ride/three-speed mixed peaks0.214/0.211/0.255;
isolated speed-preview kerb peak0.234. Every final150ms pause tail is exactly
silent. The recordings are controlled presentation/contact auditions, not
complete races or a physical-device acoustic measurement.

Evidence in `docs/evidence/clean-kerb-audio-2026-10-11/`: before asset hashes,
twelve native mixed/isolated WAVs, contact timing, continuity/review reports,
repeat-build ledger, actual logs, scoped Git-format patch and checkpoint hashes.
The shared Git index is untouched; the checkpoint excludes unrelated work.

Remaining acceptance: owner listening on real kerbs, phone speakers/headphones
and chosen sound settings. **No phone listening/device test, Android export or
installation performed.** No deployment or fullValidate run. The previously
documented direct-hit collision regression is unchanged and outside this
asset-only correction; no whole-suite-green claim is made.
