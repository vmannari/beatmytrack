# Solo opening and growing ensemble

Owner subsequently rejected this opening/finale. Current listening work is the [compatible background-music bank](MUSIC_MODULAR_BANK.md); the v6 runtime has not yet been replaced.

2026-09-25, MUSIC_ENGINE_VERSION 6. MUS01/MUS03/MUS08/MUS09/MUS10. The owner rejected the v5 opening beat and requested a smoother single-instrument opening that develops into fuller harmony. This replaces v5's quiet-but-already-complete band. Clean-driving qualification, collision reset and track lookahead remain unchanged; no handling edits.

## Musical design

The opening schedules only one warm, low-register sustained melodic instrument. Its notes overlap for legato continuity (up to two voices of the same instrument); there is no kick, snare, hat, pulsed bass, repeated guitar chord or noise attack. The authored E3-G3-B3-A3 motif stays below the previously rejected high synth register. Smoothstep attack is 320 ms, release 650 ms. This is a new synthesis candidate, not an approved acoustic sound.

At bar boundaries, rising energy adds roles in order:

| Energy | Newly added role |
|---|---|
| Opening | Solo sustained melody |
| Above .28 | Three-note inner harmony: Em, Em7, Cmaj7, Am7 voicings |
| Above .44 | Low bass foundation |
| Above .60 | Restrained kick/snare/hats |
| Above .74 | Original rock rhythm-guitar riff |
| Above .86 | Low answering melodic line |

The bass follows the guitar once that riff enters. All parts remain within the same original minor-key palette, with authored passing notes. New layers enter on bar boundaries; gain changes remain smoothed. This draws on the compositional idea of solo-to-ensemble growth rather than transcribing any classical piece. No recordings, samples, runtime AI or services.

Collision recovery returns to the solo texture with a descending E-D-C-D line, allowing old parts' short release tails to fade. Clean driving rebuilds the ensemble as before. Finish cadence is unchanged. Musical richness and the emotional effect need listening review; tests cannot certify those qualities.

## Audition and implementation

[48-second production-core preview](evidence/music-ensemble/solo-to-ensemble.wav): approximately 0-8 s solo, 8-32 s gradual build, 32-40 s full ensemble, 40-48 s collision recovery. Musical entries are bar-quantized, so exact entrance times vary slightly. It uses constant gain throughout, without section normalization; game player gain adds another -9 dB. The offline driver sets the energy arc directly to make every stage audible; actual racing earns it from sustained clean speed.

`native/music/synth.hpp` adds a fixed ten-slot soft-voice pool with a precomputed sine table; no per-sample allocation or oscillator transcendental calls for these voices. The physical-string pool is reduced from 24 to 18 slots, preserving a total maximum of 32 including four mono drum/bass parts. Layer-mask telemetry is atomic. F8 displays the current named orchestration stage. Seed/version and Windows/Android libraries advance together to v6. `render_ensemble.cpp` is an offline reviewer, outside the export root.

Changed files: native DSP/extension/build configuration/test/renderer; Godot version and native manifest/libraries; debug stage display and evidence paths; native-playback intro assertion; this documentation and status notes. Existing progression mapping and vehicle physics are unchanged.

## Verification and limits

Actual commands and results:

- Compile/run `native/music/test_synth.cpp` with `C:/msys64/mingw64/bin/g++.exe -std=c++17 -O2 -static`: pass. Existing exact same-seed PCM, divergent track variants, render allocation guard, finite/bounded output, timing, pause, finish, hysteresis and 44.1/48/96/192 kHz coverage retained. New assertions prove solo-only opening (maximum two overlapping notes), all five additional layer stages in order, and solo recovery. Full render peak 25/32 voices; RMS .080207, maximum sample .295107, before player gain.
- Compile/run `native/music/render_ensemble.cpp` with the same compiler/options, output `docs/evidence/music-ensemble/solo-to-ensemble.wav`: 48 seconds of production DSP, finite/bounded PCM verified while rendering.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BuildMusic`: all four native Windows/Android debug/release builds pass.
- Same entry point `TestMusic`: **36 checks pass**, including the actual native stream reporting solo-only layers at race start.
- `CaptureMusicDrive`: **38 checks pass**. Desktop six-second intro: two peak voices, layer mask 1, sampled mix 132 us / maximum 376 us, zero render-budget overruns, controller sample 33 us. These measure the intro, not sustained full-ensemble phone CPU.
- `CaptureMusic`: lab screenshot inspected, as was the driving screenshot. Both show the named Solo stage and two overlapping notes; all lab controls remain visible. `TestMusicExit`: 64 immediate create/free cycles complete without crash, with the existing abrupt-shutdown pending-object warning. Normal-lifetime release assertion still passes.
- `ExportAndroid -QuickValidation`: import/startup, 74 driving, 18 catalog and 26 menu checks pass. Final APK export/signature outcome recorded in `android-export.log`. Full physics regression is unnecessary for this presentation-only change and was not run.
- `adb devices`: empty device list. No Android installation, phone driving or acoustic test was performed. The APK is available at `build/android/circuit01-debug.apk` after export. Existing unrelated visual work remains in the shared-workspace APK but outside this checkpoint.

Evidence logs and screenshots are under `docs/evidence/music-ensemble`. Remaining acceptance: listen to the solo timbre, chord balance, progression pacing and full ensemble on repeated laps; test phone CPU/audio, focus/resume and thermal stability. The music is not claimed to sound spectacular or approved merely because tests pass.
