# Clean-driving music progression

2026-09-25, MUSIC_ENGINE_VERSION 5. Owner request supersedes geometry-led intensity and automatic final-lap maximum energy. MUS01/MUS03/MUS05/MUS08/MUS09/MUS10; R01/V03/V05/Q01 remain applicable. Grass only, rock instrument identity retained.

## Behaviour and tuning

Each race/retry starts with sparse, soft E-root guitar chords, restrained kick/hat and a light backbeat. No high synth is added. A three-second exponential average of forward speed must reach 10 m/s (36 km/h) and qualify for four seconds before intensity begins rising. It takes another 24 qualifying seconds to reach maximum. The speed threshold has 1 m/s hysteresis; brief corner braking is absorbed by the speed average. Sustained low speed drains a full build over 12 seconds after qualification is lost. These are tuning defaults, not final balance.

An increase in the existing `VehicleState.collision_count` immediately clears earned intensity, speed average and qualification, then holds recovery for five seconds. Continuing contacts renew that hold. The mix smooths down without a hard cut; the next bar switches to sparse low E-D-C-D power chords for a slightly melancholic response. This is an authored mood intention requiring listening approval. Clean driving earns the music back: recovery mood clears at 30% rebuilt intensity, on a bar boundary in the sequencer. Pause/countdown and race finish freeze progression; retry resets it. Lap changes do not reset progress or force energy upward. Existing finish cadence remains.

All seven tuning fields are inspector-editable in `MusicProfile` under **Clean driving progression**. Speed means positive velocity along the vehicle's heading, so reversing/sideways motion does not earn forward pace. Here **clean** specifically means no counted collision; this slice does not introduce off-road penalties, course-completion rewards, collision-severity grading or physics changes. A slow/tight track may not sustain 36 km/h; adjust the profile threshold after driving feedback.

## Integration and data flow

`VehicleState.velocity/forward()/collision_count` -> `DrivingMusicProgress` -> earned intensity + recovery mood -> `DynamicMusicController` -> smoothed E/T/H + context bit 8 -> native bar-aligned arrangement. No canonical simulation writes. Presentation updates use elapsed delta; tests compare 20 and 120 Hz.

Cached track geometry and trajectory lookahead still colour earned energy, hook openness and tension. They cannot force the opening or recovery into a full arrangement. The controller caps recovery targets even on the final lap. The native synth has sparse, medium and full rhythm stages; energy also smoothly changes amp input and bass/drum levels. Recovery changes only a fixed low-register phrase; full intensity returns to the accepted original riff. Structural changes remain bar-aligned at fixed 128 BPM.

`DrivingMusicProgress` is a separate GDScript state model; `DynamicMusicController` reads it every presentation update, while geometry stays at 10 Hz. Existing lock-free native controls carry the mood bit, avoiding a new per-sample API. `synth.hpp` retains its fixed 24-string pool and four mono parts. New smoothing coefficients are computed during construction, not per sample. Native and track seed versions both change to 5; build and manifest use v5 library names.

## Review tools

F8 adds average speed in km/h, earned build percentage, clean qualification time and recovery countdown/mood. Route graphs remain visible. Music Lab starts calmly; **Clean build** simulates sustained 65 km/h using the same progression model, and **Collision** resets it. Road-scenario buttons return to manual E/T/H auditioning. Restart clears progression. Final lap deliberately cannot bypass the clean-driving requirement.

Changed files: `game/music/driving_music_progress.gd`, `dynamic_music_controller.gd`, `music_profile.gd`, `music_test.gd`, `music_debug.gd`, version/manifest/native libraries, `native/music/synth.hpp`, `SConstruct`, both music test files, status/architecture docs and evidence. No gameplay/controller/handling edits are included in this checkpoint.

## Verification

Actual commands and outcomes:

- `C:/msys64/mingw64/bin/g++.exe -std=c++17 -O2 -static native/music/test_synth.cpp -o build/music-progression-test.exe`, then `./build/music-progression-test.exe`: pass. Existing determinism/variant/allocation/bounds/clock/pause/finish/hysteresis/sample-rate/tempo checks retained. New checks verify calm power below 70% of full power, sparse opening, collision mood at the next bar even with high energy, and return to full arrangement after recovery. Peak 16 voices, RMS .086245, maximum sample .289716. No listening claim.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BuildMusic`: Windows and Android debug/release native builds pass. New script registration required `Import` before tests (the first pre-import attempt reported the new global class missing).
- Same entry point `TestMusic`: **35 checks pass**, including initial calm, burst rejection, sustained build, collision reset/hold, pause, recovery, slowing down, restart, 20/120 Hz agreement and final-lap collision priority.
- `CaptureMusicDrive`: **37 checks pass**. Inspected driving screenshot shows calm mode and zero earned build at six seconds, average speed 32.5 km/h. Native v5: 10 peak voices, sampled mix 149 us / maximum 766 us, 512 frames / 48 kHz, zero render-budget overruns. Controller sample 34 us. Short desktop observations only.
- `CaptureMusic`: new buttons and expanded overlay captured and visually inspected. `TestMusicExit`: 64 immediate start/free cycles complete without crash; abrupt shutdown reports 64 pending ObjectDB objects as in previous versions. Normal-lifetime release test still passes without weakening its deadline.
- `ExportAndroid -QuickValidation`: import/startup, 74 driving, 18 catalog and 26 menu checks pass; Android export/signing verification passes. ZIP contains the v5 ARM64 library. Full physics regressions were not run because no canonical physics changed.
- Attempted `scripts/profile-features-phone.ps1 -TrackId track_1e3936d025fe7c82 -Baseline -Seconds 45 -ReportName music-progression-phone`: **not run on device**. ADB reported no devices before installation. The updated APK is `build/android/circuit01-debug.apk`; the phone still has the previous build unless separately installed. No physical phone was attached at deployment time.

Evidence: `docs/evidence/music-progression` (native/Godot/build logs, screenshots and failed device-availability log). APK includes existing shared-workspace visual changes; this checkpoint excludes unrelated source edits.

Remaining acceptance: speed threshold and qualification/build duration across slow and fast tracks/cars; repeated collisions; perceived melancholy; gradual build and sound-effect balance by ear; Android driving/audio/focus/resume and thermal checks. The clean-driving state is based on the existing collision count, without impact-severity filtering. No OS-level audio-underrun or acoustic quality claim.
