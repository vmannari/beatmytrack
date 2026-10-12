# Sound effect timing correction - 2026-10-08

The owner reports collision sound slightly after the visual contact and requests
sound-effect timing checks. SND11 refines SND08/SND05 and supports G01/R01/Q01/V06:
play contact feedback as soon as the post-simulation observer receives it, keep
contact attacks short, preserve cooldown/pause/countdown/rewind guards and the
canonical simulation.

Two actionable delays were found. `Game` already calls
`vehicle_audio.collision()` immediately after `sim.step()` produces the contact
observer, alongside the camera/car feedback. `VehicleAudio` previously retained
that impulse until `present()` ran after render/presentation work. It now starts
the selected body voice inside the collision observer call. The unused queued
impact state is removed; cooldown and direct-impact history remain resettable.

The three collision masters have their main peak near 4 ms, with 10%-of-peak
attack within 0.6-1.1 ms. The three underside-grit masters also peak near 4 ms.
Those six source clips did not need trimming. The chassis source used for kerb,
landing and virtual-shift feedback peaked **103.673 ms** after the start. Its
existing cleared Nox body transient is now cut/enveloped to peak **3.991 ms**
after the start. No new source, generator, dependency, physics/rules/content
version, saved player file or backend change is introduced.

## Measured comparison

The diagnostic runs the actual pinned engine's mixer and collision observer in
a clean graphical process. A controlled contact and quiet reference pulse are
started together, followed by a deliberately injected **30 ms presentation
workload**. Reference and raw vehicle PCM are recorded on the same mixer clock;
the master capture retains the normal dynamics and both peak limiters. Five
separate trials reset cooldowns and use identical contact force/pitch/volume.
This exposes dispatch waiting; it is not a claim that ordinary frames always
have 30 ms workload or a microphone measurement of a real crash/phone speaker.

| Measured value | Before | After |
| --- | --- | --- |
| Collision played within the observer call | No | Yes, all five trials |
| Median raw collision/reference onset separation | 32.042 ms | 0.042 ms |
| Raw separation range | 21.375-42.708 ms | 0.042 ms in all five trials |
| Chassis source main peak | 103.673 ms | 3.991 ms |
| Collision/grit source peaks | About 4 ms | Exact same six files/hashes |

The raw onset detector uses amplitude >40/32768; the marker is a short quiet
alternating PCM pulse. The master uses a higher threshold to distinguish the
collision from the reference. The detected raw onset is not the main waveform
peak, which remains about 4 ms into the collision source. PCM/device buffers,
the platform's mixer and frame scheduling remain outside an instantaneous
observer call; **zero acoustic latency is not claimed**.

The pinned Windows build reports **WASAPI, 48 kHz and about 10 ms output
latency**, with the existing default preferred setting of 15 ms. The output
estimate is separate from the recorded digital bus timing. No buffer-setting
or limiter removal was used to make the result faster. Godot documents the
[next-mix/output latency distinction](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html)
and notes that the requested output latency is constrained by hardware and
[ignored on Android](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-audio-driver-output-latency).
Its current upstream hard limiter has a fixed 2 ms lookahead per instance
([header](https://github.com/godotengine/godot/blob/master/servers/audio/effects/audio_effect_hard_limiter.h),
[implementation](https://github.com/godotengine/godot/blob/master/servers/audio/effects/audio_effect_hard_limiter.cpp));
these remain in the pinned runtime mix, whose master capture trails raw contact
onset by about 4.27 ms at the chosen detection thresholds. Upstream source is
context; the actual pinned-engine measurements are the acceptance evidence.

[Listen to before/after PCM and chassis attacks](evidence/effect-timing-2026-10-08/audition.html).
Numeric results, all seven source attack measures, the original bank manifest,
paired WAVs and capture hashes are in `timing-report.json` and the evidence
checkpoint. No visible product UI changes; audio is the presentation evidence.

The bank remains **45** clips and **21** bounded race voices. Only `chassis.wav`
changes; all other **44** clip hashes are identical to the task-start bank.
Total WAV bytes are **9,394,258** (5,292 fewer). Attribution and source hashes
remain in `manifest.json`, shipping `NOTICE.txt` and the asset ledger. The earlier
surface-art and band/music work remains preserved.

## Actual commands and outcomes

Every Godot command uses `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1` and **4.7.2.stable.official.ed1daf0bf**.

| Actual command / suffix | Actual result |
| --- | --- |
| `TestScript -ScriptPath res://tests/probe_effect_timing.gd -Graphical` | WASAPI/48 kHz, estimated output 10 ms; no Android-specific setting. |
| `TestScript -ScriptPath res://tests/capture_effect_timing.gd -Graphical` before and after | Five valid paired trials each; median 32.042-to-0.042 ms under the controlled 30 ms workload. |
| `python scripts/build_vehicle_audio.py` | 45 clips; chassis reauthored, 44 other hashes unchanged; maximum bank peak -1.514 dBFS. |
| `Import` | Exit 0 with rebuilt lossless audio and timing scripts. |
| `TestScript -ScriptPath res://tests/test_effect_timing.gd` | 40 checks, zero failures: synchronous light/medium/heavy playback, no render duplicate, cooldown, tiny-contact threshold, pause/countdown/resume, rewind clearing and all seven main peaks inside one 120 Hz tick. Final shutdown is clean. |
| `TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | 1,438 checks, zero failures. |
| `TestScript -ScriptPath res://tests/test_surface_impact_audio.gd` | 67 checks, zero failures. |
| `TestScript -ScriptPath res://tests/test_desert_audio.gd` | 25 checks, zero failures. |
| `TestScript -ScriptPath res://tests/test_shallow_collisions.gd` | 20,268 checks, zero failures; 46 ObjectDB shutdown warnings retained in the log, not reported as a clean shutdown or proven runtime leak. No physics assertion is weakened. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | 366 scripts, zero failures. |
| `TestApp` / `TestRewind` | 99 / 57 checks, zero failures. |
| `python scripts/review_effect_timing.py` | Timing bounds, five paired trials, all seven attack bounds and exact 44 unchanged derivative hashes verified; local listening artifact/report produced. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/effect-timing-2026-10-08/loop-continuity.json` | 38 loops, zero failures, including wrap/three-repeat/dropout checks. |
| `Doctor` | DN2103 attached; no phone audio timing test. |
| `python -m py_compile scripts/review_effect_timing.py scripts/surface_audio_mastering.py` | Exit 0. |
| `git diff --check -- DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md licenses/ASSETS.md` | Exit 0; existing CRLF normalization notices retained. |
| `python docs/evidence/effect-timing-2026-10-08/make_checkpoint.py` | 57 pinned files/17 retained logs; task-scoped `git apply --reverse --check --ignore-whitespace` exits 0. |

The first repeated baseline forgot to advance/reset cooldown between trials:
only its first impact was valid. `failed-cooldown-baseline.json` and the initial
log remain; all accepted before/after numbers come from five fresh trials. An
initial fast headless timing test reported shutdown references still queued;
waiting two process frames after freeing audio yields the final clean exit.
An intermediate baseline-save inline shell quoting error was corrected with an
explicit helper script. None of these failures was accepted as a passing timing
measurement or fixed by weakening the collision/lifecycle checks.

## Files and remaining acceptance

Runtime: `game/vehicle/vehicle_audio.gd`. Offline mastering:
`scripts/surface_audio_mastering.py`, bank revision in
`scripts/build_vehicle_audio.py`, `chassis.wav` and manifest/notice. Test contract:
`test_vehicle_audio.gd` and `test_shallow_collisions.gd` now check reset direct
impact history rather than the removed queue; new `test_effect_timing.gd`,
`probe_effect_timing.gd`, `capture_effect_timing.gd` and their UIDs; new
`scripts/review_effect_timing.py`. Docs: this file, the link in
`SURFACE_IMPACT_AUDIO.md`, status/phase/provenance notes and the task-scoped review
patch/hash inventory. `game/core/game.gd`, project audio settings, bus layout and
canonical simulation are unchanged by this task.

Owner driving/listening, phone speakers/headphones and any Bluetooth path remain
unverified. No phone acoustic measurement, Android export/install, full Validate,
backend action or production deployment was performed. Actual sound/visual
alignment on the device cannot be inferred from PCM timing alone. The review
checkpoint preserves concurrent work without changing the shared Git index.
