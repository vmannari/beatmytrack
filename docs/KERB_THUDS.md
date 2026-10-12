# Synthesized kerb thuds — 2026-10-11

Owner requests a synthesized **thud-thud-thud** sound after rejecting the
continuous flutter. **SND53**, refining SND47/SND50–SND52 and supporting
G01/R01/Q01/V06 sound presentation and lifecycle separation.

Replace the flutter with **six rounded rubber/body thuds per second** at native
pitch. Each original synthesized pulse has a2.5ms soft attack constant, a brief
resonance fall from about150Hz to105Hz, a low-passed contact transient and a
27ms damped tail with a final release. Small pitch/gain variation keeps the
body response from being identical every time. A quiet low bed connects the
tails; no field recording, metallic click train or microphone background.
Existing runtime speed pitch0.65–1.35 gives roughly3.9–8.1 thuds/s.

Critically, kerb mastering now **preserves each thud's attack/decay** instead of
flattening it with100ms texture leveling. The existing loop-wrap/embedded-gap
checks remain unchanged and pass. No other surface's mastering is changed.
The result remains7.5s/661,544-byte mono44.1kHz/16-bit PCM. Generator/seed and
6Hz native rate are in the bank manifest. Actual mastered10ms RMS-envelope
spectrum peaks6.006Hz;95th/5th percentile amplitude contrast is17.77 instead
of2.50 in the rejected flutter. Spectral energy80–1750Hz is99.78%.

Real-wheel kerb detection/sweep/40ms presentation hold, entry bump, speed mix,
grass onset and immediate silence gates remain unchanged. Bank49 clips/race23
bounded players are retained. All **48 other WAV hashes** are exact, including
the owner's crash and Pól rail scrape. No runtime synthesis/new dependency,
canonical physics, geometry, rules, UI or backend changes.

Changed files: `scripts/kerb_audio_mastering.py`, `build_vehicle_audio.py`,
`review_kerb_refinement.py` (revision5 provenance audit),
`game/assets/audio/vehicles/kerb_roll.wav`, `manifest.json`, `NOTICE.txt`,
this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands/results:

| Command | Outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --kerbs-only` | One661,544-byte clip; repeat all49 WAV hashes exact. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` | Exit0, pinned4.7.2.stable.official.ed1daf0bf. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,454 checks/zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/kerb-thuds-2026-10-11'` | **78 checks/zero failures**, contact/lifecycle/canonical separation;12 native captures with5/18/36m/s engine mix. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/kerb-thuds-2026-10-11/loop-continuity.json` | **42 looped assets/zero failures**, retained wrap and embedded-gap assertions. |
| `python scripts/review_kerb_refinement.py --evidence-dir docs/evidence/kerb-thuds-2026-10-11` | **12 captures pass**, audibility/headroom/pause/no false kerb on grass, spectrum/no recorded source and48 other WAVs exact. |
| `python build/review_kerb_thuds.py` | Actual pulse6.006Hz and17.77 attack/tail contrast; distinct-thud assertion passes. |
| `python -m py_compile scripts/kerb_audio_mastering.py scripts/build_vehicle_audio.py scripts/review_kerb_refinement.py` | Exit0. |

Actual Game fixture: two axle/contact bumps, rumble gain peak0.401, zero
collisions. Native crossing/ride/speed mix peaks0.253/0.292/0.359; isolated
speed-preview peak0.311. Every final150ms pause tail exactly silent. Auditions
are controlled contact/presentation poses, not completed races or physical
mobile acoustic measurements. The previous direct-hit collision regression
remains unchanged; no whole-suite-green claim.

Evidence: `docs/evidence/kerb-thuds-2026-10-11/`, including twelve native WAVs,
contact timing, shape/spectrum/continuity/headroom/hash audits, actual logs,
scoped Git-format patch and checkpoint hashes. Shared Git index untouched;
unrelated work excluded. Remaining acceptance is owner listening on actual
kerbs and phone speakers/headphones. **No phone listening/device test, Android
export/installation, fullValidate or deployment performed.**
