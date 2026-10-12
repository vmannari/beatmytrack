# Runtime engine-layer transition correction — 2026-10-10

The owner still hears artefacts and now suspects another audio track entering
the mix. **SND37** investigates runtime layer introduction; **SND02–SND06,
SND33–SND36/G01/R01/Q01** preserve bank provenance, lifecycle, source loop repair
and canonical isolation. The triggering situation/platform question remains
unanswered; the exact reported sound still requires owner listening.

No new file loads during ordinary engine blending: all six engine voices already
play at muted/variable gains. The controlled captures retain the same **22 cached
streams**, with no shifts or body events. Two actual mixing defects were found:

1. Earlier bank changes made the recorded firing pulses coherent, but playback
   still used equal-power fades intended for unrelated signals. Ideal aligned
   neighboring banks rose by roughly **2.43–2.96 dB** at their midpoint. The load
   and coast variants had the same overlap-gain problem. The previous sound work
   left this incompatible gain rule in place.
2. Voices started at native bank pitch instead of the engine's idle pitch, and
   muted banks clipped their rate to 0.35–2.85. They could drift out of phase while
   inaudible, then partially cancel the current bank when reentering the mix.
   A gain-only candidate exposed a roughly **6.18 dB** low/mid dip and was not
   accepted as the final correction.

`EngineAudioBlend` now normalizes RPM weights and load/coast gains for coherent
signals. Full-load gain and the 0.84 coast attenuation remain at their endpoints;
overlap no longer boosts their sum. `VehicleAudio.reset` assigns the idle ratio
before every engine voice starts. All engine voices, including muted ones,
continuously follow `model.rpm / model.anchors[i]` without the clipping that
changed their clocks. Valid sound-model bounds keep ratios positive, approximately
0.1615–6.19 across all five cars. The cyclic PCM regression now tests 0.16–6.2 too.

The abstract drivetrain's equal-power weight contract remains unchanged; the
normalization applies at playback. Physical handling, simulation, car configs,
controls, timing, camera, RPM/gears/shift timing, body/gear cues, surface gating,
audio buses and every vehicle waveform remain unchanged. No new voice, asset,
runtime synthesis or dependency is added.

[Listen to the exact before/after runtime transition captures](evidence/audio-layer-transitions-2026-10-10/audition.html).
[Numerical review](evidence/audio-layer-transitions-2026-10-10/review.json).
Four cases hold endpoints, traverse the blend, hold, return and pause: low/mid,
mid/high, full low-to-high-and-return, and throttle/coast. All eight native
15-second recordings are audible/unclipped, end with a digitally silent
half-second and preserve state snapshots. A fixed envelope and zero virtual
shift cooldown progression isolate the blend; these are synthetic presentation
states, not a completed race or acoustic microphone captures.

| Measured defect | Before | Final after |
| --- | --- | --- |
| Low/mid handover RMS dip | -2.098 dB | -0.737 dB |
| Full RPM excursion/reentry RMS dip | -2.278 dB | -0.673 dB |
| Throttle/coast overlap gain | +1.591 dB | -0.461 dB (no overshoot) |
| Mid/high overlap gain in initial startup run | +2.911 dB | +0.020 dB in final run |

The old midpoint result depends on initial phase; a later warmed baseline
mid/high run happens to be nearly flat. That does not contradict the reproduced
gain/phase defects. The final cases all stay below +0.75 dB overshoot and above
-1 dB dip relative to endpoint RMS. Distinct recorded pulse shapes allow modest
sub-dB variation; the correction is not merely a blanket volume reduction.

All **47 vehicle audio files** match their original SHA-256, and **101/102** total
audio files match the turn's starting ledger. A separate concurrent edit changed
the unused `storm_thunder.wav` one-shot; its before/current hashes are recorded in
`concurrent-audio-changes.json`. It is preserved and is not part of these Engine
bus captures (all event counts are zero). The original ledger remains intact;
the report explicitly separates this external change from the pinned inputs.
No sound file was regenerated or changed by this task.

Changed files: `game/vehicle/vehicle_audio.gd`;
new `game/vehicle/engine_audio_blend.gd`/UID;
`game/tests/test_audio_loops.gd` (expanded actual pitch-range regression);
new `game/tests/capture_audio_layer_transitions.gd`/UID;
`scripts/review_audio_layer_transitions.py`; this document,
`DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and task evidence.
The shared index/unrelated work is preserved; a task-only Git-format patch and
artifact hashes provide the review checkpoint.

Actual commands, pinned `4.7.2.stable.official.ed1daf0bf` via `scripts/dev.ps1`:

| Command | Actual result |
| --- | --- |
| Local recorded-bank correlation/RMS comparison | All ten adjacent pairs 0.751–0.976 correlation; ideal old midpoint gains +2.433–2.959 dB. |
| `… dev.ps1 Import` | Exit 0; helper and native fixture registered. No audio imports changed by this task. |
| `… dev.ps1 TestScript -ScriptPath res://tests/capture_audio_layer_transitions.gd -Graphical` | Final **eight captures, zero failures**, unchanged stream counts, zero shifts/events and preserved snapshots. |
| `python scripts/review_audio_layer_transitions.py` | Final bump/dip, continuity/headroom/pause and pinned input-source checks pass; concurrent unused thunder change reported. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | Final **1,446 checks, zero failures**, including exact 960-tick simulation equivalence and real race/retry lifecycle. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_audio_loops.gd` | **212 checks, zero failures**, including new muted-bank extreme pitches, mono/stereo and all PCM factories. |
| Scoped `git diff --check` and task patch reverse-check | Exit 0. |

Initial capture had one unusable first recording; a 0.5-second native mixer settle
and retained invalid-record diagnostics corrected the fixture without weakening
duration requirements. Initial gain-only captures are retained separately. A
diagnostic Python one-liner had an extra parenthesis and was corrected. One full
vehicle run hit an in-progress unrelated `_dust_car` parse error; the untouched
concurrent dust edit settled and the full rerun passed. The original global audio
hash assertion flagged concurrent thunder editing; all capture inputs stay pinned,
the external change remains explicit, and no original hashes were rewritten.

No visible UI changed; playable sound is the presentation evidence. No phone
attachment check, device listening/performance test, Android export/install,
full Validate, backend operation or deployment occurred. Restart the local game
to load the runtime correction; installed Android builds remain unchanged.
Remaining acceptance: owner identifies the exact sound/trigger and compares the
previews with real acceleration, lift-off, repeated bank reentry, slides/surfaces,
pause/retry/rewind and device speakers/headphones. Actual gear/contact cues remain
possible separate sources; the measured correction does not establish that every
remaining audible artefact has been identified.
