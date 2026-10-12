# Slower kerb pulse — 2026-10-11

Owner requests a lower-frequency repeating kerb pattern. **SND52**, refining
SND51/SND50/SND47 with G01/R01/Q01/V06 presentation separation.

Reduce the authored amplitude-flutter rate from **24Hz to8Hz**: one pulse
about every125ms instead of42ms at native pitch. Preserve the clean underlying
rubber/body rumble, shallow flutter depth, smooth phase/pressure variation,
EQ, loudness and continuous bed. This changes the repetition rate, not the
underlying sound's pitch. Existing speed pitch0.65–1.35 gives approximately
5.2–10.8 pulses/s instead of15.6–32.4. Kerb detection, entry bump, grass and
canonical physics remain unchanged; there is no field recording or runtime
synthesis in the loop. The mastered7.5s/661,544-byte PCM and bounded49-clip/
23-player budgets remain. All **48 other WAVs** are exact, including accepted
crash and rail scrape.

Changed files: `scripts/kerb_audio_mastering.py` (24→8 phase rate),
`build_vehicle_audio.py` (revision/generator/pulse-rate provenance),
`review_kerb_refinement.py` (revision4 source audit),
`game/assets/audio/vehicles/kerb_roll.wav`, `manifest.json`, `NOTICE.txt`,
this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.
No runtime GDScript, handling, geometry, UI or backend changes.

Actual commands/results:

| Command | Outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --kerbs-only` | One661,544-byte clip; repeat all49 WAV hashes exact. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` | Exit0, pinned4.7.2.stable.official.ed1daf0bf. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,454 checks/zero failures**. |
| Same launcher, `-Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/slower-kerb-pulse-2026-10-11'` | **78 checks/zero failures**, contact/lifecycle/canonical separation and12 native captures including5/18/36m/s mix. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/slower-kerb-pulse-2026-10-11/loop-continuity.json` | **42 loops/zero failures**, joins/no embedded gaps. |
| `python scripts/review_kerb_refinement.py --evidence-dir docs/evidence/slower-kerb-pulse-2026-10-11` | **12 captures pass**, no field source/headroom/pause tails/kerb audibility/48 other assets exact. |
| `python build/review_kerb_pulse.py` | Actual mastered10ms RMS-envelope spectrum peak **24.023→8.008Hz**, periods41.63→124.88ms. |
| `python -m py_compile scripts/kerb_audio_mastering.py scripts/build_vehicle_audio.py scripts/review_kerb_refinement.py` | Exit0. |

Actual Game remains two axle/contact bumps, rumble gain0.401, zero collisions.
Native crossing/ride/speed mix peaks0.206/0.215/0.300; all final150ms pause
tails exactly silent. These are controlled native presentation/contact auditions,
not full races or phone acoustic measurements. Existing direct-hit collision
regression is unchanged; no whole-suite-green claim is made.

Evidence: `docs/evidence/slower-kerb-pulse-2026-10-11/`, with before hashes,
twelve native auditions, contact timing, pulse/continuity/review reports,
repeat-build hashes, actual logs, scoped Git-format patch and checkpoint ledger.
Git index/unrelated work untouched. Owner listening to the slower rhythm remains
the sound-quality acceptance. **No phone listening/device test, Android export/
installation, fullValidate, backend change or deployment performed.**
