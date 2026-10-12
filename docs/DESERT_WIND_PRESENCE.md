# Continuous, louder desert wind — 2026-10-11

SND45 refines SND44/SND42: the owner finds wind too quiet and wants sound
throughout the race. G01/R01 preserve canonical driving; Q01 covers actual audio
verification and provenance.

Steady wind gain increases0.15→0.38, retaining the0.12 gust lift and raising its
maximum0.297→0.55. After the existing two-second opening fade, gain never falls
below0.342 (0.38 times the minimum race multiplier0.90). Smooth gusts, randomized
variants/phases and no immediate Retry repeats remain. Pause/background/mute and
finish deliberately retain their existing silence behavior.

The same three owner-recorded wind sections are gently leveled offline: circular
0.75-second RMS measurement and0.5-second smoothed gain lift quieter passages,
bounded0.45–4.0, with a−5dBFS peak ceiling. This changes loudness dynamics while
retaining recorded waveform shape/pitch and avoiding added wind noise or EQ.
The original MP3/source metadata are retained unchanged. Export-excluded gain
profiles and SHA256 metadata permit checking the exact source-to-master mapping.
Both PCM joins remain power-preserving, with zero quantized boundary steps.

No new voices or runtime processing/dependencies. The same two ambience voices
play pre-rendered12/14/12-second wind variants plus the original29-second sand.
Sand WAV/gains, vehicle sounds, physics, UI, rules/track/car contracts, five laps
and backend are unchanged. Total shipped audio remains5,909,576bytes. Only the
three wind WAVs change; their rebuild hashes repeat exactly.

Changed files:

- `game/track/desert_ambience.gd`: stronger steady gain and bounded maximum.
- `scripts/build_desert_ambience.py`: smooth offline leveling, peak control and quantized seam selection.
- `game/assets/audio/ambience/desert_wind{,_b,_c}.wav`, `desert_ambience_manifest.json`, `NOTICE.txt`.
- `game/tests/test_desert_ambience.gd`: wind-floor check, original proportional transition bound, bus-isolated component captures and controlled engine/ambience mixes.
- `scripts/review_desert_ambience.py`: leveled-source fidelity, stronger presence thresholds, prior-sample comparison and controlled full-mixer continuity/clipping checks.
- `docs/DESERT_OWNER_WIND.md`, this document, `licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands, pinned Godot4.7.2:

```powershell
python scripts/build_desert_ambience.py
# Repeated: all four audio hashes reproduce exactly, including unchanged sand.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd -Graphical -TestArgument @('--capture','--components-only')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python scripts/review_desert_ambience.py
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
```

Import/headless111/native full133/component120/App99 and final PCM review pass.
The final headless111 checks use the exact original proportional transition
limit0.004/0.297 at the louder scale. Fixed absolute gain-step expectation is
superseded by the explicit louder-volume request, while transition shape/time,
pause/finish, shuffle coverage, PCM join and canonical-state assertions remain.

Wind component samples are approximately6–14dB louder than SND44. Their settled
50ms windows remain above0.015RMS; the two20-second ambience mixes remain
continuous and vary between races. Masters have zero endpoint steps and seam
energy ratios0.960/1.023/1.023. Source waveform correlation after the documented
leveling gain is>0.99999999. All recordings are unclipped; pause/mute/finish
samples are exactly silent. Native playback crosses all three wind loops and
the sand loop.

Controlled8-second Compact mixer samples at idle and25m/s (90km/h) add the real
engine/vehicle layers, plus separately recorded same-clock engine and ambience.
Background RMS is−31.414/−31.482dBFS versus engine−29.016/−23.168dBFS. Every
settled500ms background window stays above0.02439/0.02284RMS, preserving a
continuous bed. Full mix peaks0.1779/0.2520 and has no clipped samples. These
are controlled mixer scenarios, not actual completed races, subjective listening
or a claim about every vehicle/device/output level.

Initial diagnostic corrections are retained: a pre-export wind seam differed by
one PCM unit, so the builder now requires an exactly matching quantized boundary
before selecting a locally balanced seam. An isolated sand capture briefly
included wind while per-frame volume overrides raced the audio thread; dedicated
muted component buses remove that leakage and a sand-only peak ceiling is now
checked. First component rerun exposed GDScript ternary typed-array assignment;
explicit `assign()` fixed it. The next attempt encountered a Windows WASAPI
buffer error; a fresh retry passed120. No other engine process or OS audio
service was stopped. Final full-mixer samples come from the successful133 run;
components come from the final isolated120 run and the combined review passes.

Evidence: [ambience preview](evidence/desert-wind-presence-2026-10-11/mixed0.wav),
[driving mix](evidence/desert-wind-presence-2026-10-11/driving.wav),
[idle mix](evidence/desert-wind-presence-2026-10-11/stationary.wav),
[measured report](evidence/desert-wind-presence-2026-10-11/review.json), component/
silence recordings, initial diagnostic report, focused logs and task-only Git
checkpoint/patch in the same evidence directory. Main index/branch and
concurrent work remain untouched by the checkpoint.

One authorized DN2103 phone is attached (inventory differs from the prior
OPD2403 tablet). No phone listening, Android export/install, device performance,
full Validate, backend work or deployment was performed. Remaining acceptance:
restart/rebuild, compare the previews and listen on the actual phone at the
owner's sound/output volume, checking continuous wind with the engine and
pause/rewind/finish. No UI change, so screenshots are unnecessary.
