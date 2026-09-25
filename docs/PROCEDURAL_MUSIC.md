# Beat My Track procedural music — Grass listening milestone

Current sound revision: [v6 solo-to-ensemble arrangement](MUSIC_ENSEMBLE.md) replaces the v5 opening beat while retaining the clean-driving state model.

2026-09-25. MUSIC_ENGINE_VERSION **6**. Requirement IDs below describe this owner-requested local slice; R01/V03/V05/Q01 also apply. Canonical handling, race rules and track formats are unchanged.

## Current progression override (v5)

The owner now wants sustained clean driving to lead the musical arc. [Clean-driving progression](MUSIC_DRIVING_PROGRESSION.md) documents the calm opening, speed-average qualification, gradual build, collision recovery, tuning and current checks. This supersedes the v4 geometry-led intensity and automatic final-lap boost described historically below. The existing rock instrument family, predictive track shading, sample clock and finish cadence remain.

## Try it

Race an existing **Grass** track (internal biome `pine`) normally. Music starts with driving, pauses with the race and resets on retry. **F8** toggles the developer overlay and route-state graph; **F7** toggles music mute without changing effects. Other biomes are deliberately silent pending Grass acceptance. The separate Music bus and conservative gain leave the existing tyre/environment/UI audio alone. This is not a masking guarantee; relative balance needs listening on speakers/headphones/phone.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 MusicLab
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMusic
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureMusicDrive
```

Music Lab has energy/tension/hook/risk sliders, Grass selection, BPM, six road scenarios, off-track risk, final lap, finish, restart and mute. BPM changes restart the audition; gameplay BPM is fixed. Scenario buttons set musical targets, not a fake physics simulation. F8's distance graph is populated during racing. Lab only lists the implemented biome.

The owner accepted the [15-second rock audition](evidence/music-reference/revision-04-rock.wav) for an in-game trial after rejecting the original high synth palette. Runtime v4 promotes its physical strings, amp/cabinet, authored E-minor riff, bass and dry drums at **128 BPM**. No upper synth lead, pluck, pad or tension oscillator remains. The earlier synthesis checklist is superseded by that explicit sound direction. Game gain remains -9 dB for SFX headroom; the offline audition was separately normalized, so loudness differs.

Current screenshots and checks: `docs/evidence/music-rock`. Earlier `docs/evidence/music` files document the rejected v1 implementation.

## Architecture and ownership

```mermaid
flowchart LR
    A[Compiled NativeTrack + creator road semantics] --> B[TrackMusicAnalyzer: cached circular 2 m map]
    B --> C[DynamicMusicController: 10 Hz spatial query]
    V[Read-only VehicleState + TrackSession] --> C
    V --> T[TrajectoryMusicAnalyzer: six constant-yaw projections]
    T --> C
    C --> S[Smoothed energy / tension / hook + race flags]
    S --> Q[Lock-free atomic controls]
    Q --> N[Native Synth: sample clock + sequencer + 24 string voices + 4 mono parts]
    N --> M[Music bus]
    N --> D[Atomic telemetry / BeatClock read model]
    D --> U[F8 overlay + route-distance graph]
    B --> U
```

| Requirement | Implementation / boundary |
|---|---|
| MUS01 native synthesis | `native/music/synth.hpp`, `extension.cpp`; no GDScript sample loop |
| MUS02 common timing | Native sample clock; `BeatClock` exposes beat/bar/8-bar phrase and boundary times |
| MUS03 composed patterns | Original E-minor rock riff, four bars, three seeded pickup variants; bass follows guitar |
| MUS04 track analysis | `track_music_analyzer.gd`; 2 m target spacing, circular smoothing, curvature, widths, bridge, biome/surface, expected speed, straight ahead and semantic labels |
| MUS05 anticipatory controls | `dynamic_music_controller.gd`; current/future blend, six corridor probes, 2-second lookahead, exponential smoothing |
| MUS06 fingerprint | Versioned SHA-256 content fingerprint; 32-bit seed; excludes names, authors and publication timestamps |
| MUS07 trajectory | `trajectory_music_analyzer.gd`; read-only velocity/yaw/slip projection, risk weights .5/.3/.2; tension contribution capped by 0.1 default |
| MUS08 race context | First lap lighter; final-lap energy/hook targets; maximum arrangement joins at next 8-bar phrase; finish cadence on next beat followed by three-beat fade |
| MUS09 tools | `music_test.tscn/.gd`, `music_debug.gd`, automated native/Godot tests and captures |
| MUS10 configuration | Inspector-editable `MusicProfile` / `grass.tres`; compiled pattern data and native build version |

`game/core/game.gd` only creates the controller, resets it when the race restarts, and passes presentation snapshots. No vehicle simulation or checkpoint method is modified. Cache lives with the loaded controller and is reused on retry; no player files are rewritten. Publishing does not change its fingerprint because publication-only metadata is excluded. Disk-persisted music caches are unnecessary for this first slice.

Road-piece semantics reuse `RoadPieces.samples`: loading-time spatial buckets and tangent matching associate S-bends/hairpins with the racing line. Widths and elevated flags reuse compiled track data. Raw route curvature remains the fallback for free paint and older locally supported authoring shapes. Ambiguous overlapping pieces can still need inspection; music never controls route validation.

The controller samples spatial state at 10 Hz and smooths at display cadence using `1-exp(-dt/tau)`. Native timing does not integrate display delta. Backward travel looks backward along the route. Corridor probes prevent a fast lookahead from jumping completely over a tight bend. Constant-yaw trajectory prediction is a lightweight estimate, not a duplicate tyre solver: braking, future steering changes and bridge elevation are not dynamically predicted. Geometry still dominates; risk cannot rewrite notes, harmony, tempo or the fingerprint.

## DSP and sequencing

The audio callback owns a fixed pool of 24 damped fractional-delay strings plus four monophonic bass/drum parts. Each chord excites six strings with deterministic filtered noise. Rings are allocated before mixing (4096 cells per voice; active ring length depends on sample rate). Note-start excitation has a fixed upper bound; there are no allocations, locks, logs or Godot objects in render. Controls use lock-free 32-bit atomics. Drum envelope/filter coefficients adapt to sample rate; string pitch uses fractional delay.

Two stereo amp/cabinet paths use a smooth saturator at twice the sample rate and low-pass filtering. This modest oversampling reduces distortion aliasing; it is not an alias-free model. Additive bass, pitched sine kick, filtered-noise snare and restrained hats complete the palette. Oldest strings are stolen only if the pool fills. Output is bounded below 0.45 per channel before player gain. No FFT, convolution, samples, runtime services or high synth voice.

The authoritative integer clock accumulates BPM units per sample over `sample_rate * 60`; eighth-note scheduling and tempo changes preserve phase. The four-bar `riffs` table contains MIDI roots and rests (-1). Chords add fifth/octave and a doubled stereo part; bass follows the root an octave below. Seeded variants alter only small authored pickups and string excitation. Drum mode changes at bars with .72/.60 energy hysteresis; the octave presence changes every four bars with .62/.38 hook hysteresis. Tension subtly shortens string gates and enables one quiet end-of-phrase snare pickup. Final-lap drums open at eight-bar boundaries; finish latches on the next beat and plays an E power chord with a three-beat fade. Geometry never directly invents notes.

Grass preset controls are brightness (cabinet cutoff), metallicity (legacy API name, now amp drive), decay (string gate length), and stereo width. Their defaults retain the accepted audition tone. This narrow trial deliberately does not add new layers or melodies.

`BeatClock` is a GDScript read model of native timing, not a second sequencer. Telemetry is quantized to 0.001 beat and reflects the rendered audio head; it is ahead of the speaker by the device buffer/latency. This does not drift. Tight visual/audible marker alignment and output-latency compensation are deferred. Gameplay runs at fixed BPM; unsupported pitch-scale/seek/loop-offset controls must not be used on this stream.

## Extend the content

1. **Tune Grass:** edit `game/music/grass.tres` in the inspector. Mapping, lookahead, smoothing, trajectory weight, BPM, gain and signature timbre live in `MusicProfile`. Restart the race to hear preset changes.
2. **Add a pattern:** edit/add bounded eight-step MIDI-root arrays in `native/music/synth.hpp`; schedule only from the native sample clock. Keep notes compatible with the E-minor riff and retain rests. Do not add runtime stochastic selection. Rebuild native libraries and run both test suites.
3. **Add a synth preset:** create another `MusicProfile` resource and route its brightness/metallicity/decay/width through `set_preset`. For new native controls, publish bounded scalar atomics outside render; never pass dictionaries or allocate voices in `_mix`.
4. **Add a biome after Grass acceptance:** map the internal track theme to a profile in `DynamicMusicController.start`, retaining the same synthesis/pattern engine. Do not create separate engines or enable an untested placeholder palette.
5. **Change identity intentionally:** increment `MUSIC_ENGINE_VERSION` in native and GDScript code, update fingerprint tests/evidence. Same inputs guarantee identical PCM on the tested build; cross-architecture floating-point PCM equality is not promised. Pattern identity is deterministic.

Further authoring conveniences (Resource-based pattern editor, separately editable transition thresholds/key/scale) are deferred. Major apex/release accents are not yet wired to individual geometry events; the present release comes from arrangement recovery. There is no saved music-volume settings UI yet; F7 is the desktop audition control.

## Build and provenance

Use the pinned Godot executable through `scripts/dev.ps1`. Native libraries for Windows x86-64 and Android ARM64 debug/release are included under `game/music/bin`. The engine's GDExtension compatibility interface uses godot-cpp 4.5 bindings with the project's pinned 4.7.2 runtime; the actual runtime tests are listed below. No downloaded code executes as a gameplay service.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BuildMusic
# Or one platform:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_music.ps1 -Platform windows
g++ -std=c++17 -O2 -static native/music/test_synth.cpp -o build/music-tests.exe
./build/music-tests.exe docs/evidence/music/grass-audition.wav
```

Close project/editor processes before rebuilding a loaded DLL. An editor open before this change may need restarting to register the final native library. A prototype DLL locked by the existing editor was retained locally and excluded from Git; the final manifest uses `bmt_music_v4` filenames.

Pinned build-only sources: godot-cpp `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77` (MIT, copied license `licenses/godot-cpp-music-MIT.txt`); SCons 4.9.1 `dfd6b7e45985eb73462d2efa878651c92745099c`. Build script verifies revisions and fetches missing source into export-excluded `.tools`. Android NDK r28b / 28.1.13356709, minimum API 24, builds with the static C++ runtime. Its official Windows archive is https://dl.google.com/android/repository/android-ndk-r28b-windows.zip; unpack under `.tools` or pass `-NdkPath` to `scripts/build_music.ps1`. The SDK manager failed to fetch manifests in this session; direct HTTPS download succeeded. No engine PATH alias was used.

All melodies, patterns, synthesis code and rendered evidence in this slice are original procedural output. No external samples, AI media, cloud calls, analytics or new runtime SDKs. The native stream follows [Godot's AudioStreamPlayback extension API](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayback.html).

## Current v4 trial verification

Requirements MUS01-MUS03/MUS06/MUS08-MUS10; existing MUS04/MUS05/MUS07 integration retained. Changed native DSP/build/library manifest, versioned track seed, preset tempo, BeatClock default, lab/debug labels, lifecycle/version tests and this documentation. No vehicle handling change.

Actual commands (2026-09-25):

- `C:/msys64/mingw64/bin/g++.exe -std=c++17 -O2 -static native/music/test_synth.cpp -o build/music-rock-test.exe`, then `./build/music-rock-test.exe`: pass. 60-second same-seed PCM, variant difference, render allocation guard, finite/0.45 bounds, clock, pause, finish, hysteresis/bar changes, plus 44.1/96/192 kHz and phase-preserving tempo change. Peak 16 total voices, RMS .091456, peak .292081 before player gain. Three renders plus additional rate tests took 4444 ms (offline throughput, not phone CPU).
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BuildMusic`: all four Windows x86-64 / Android ARM64 debug/release libraries pass. APK ZIP inspection contains only the v4 music library. Old loaded v1 files remain local and ignored; no longer tracked or referenced for export.
- Same entry point `TestMusic`: 24 checks pass three consecutive runs. An initial retirement assertion was caused by a temporary playback reference retained in the test's creating stack frame. Creation now returns weak references from a helper, ending that frame before checking; the original .25-second deadline and all-pools-retired invariant remain unchanged. No runtime lifecycle workaround added.
- `TestMusicExit`: three final 64-cycle immediate create/play/free runs exit without crash; one reports 64 pending objects at abrupt shutdown. This is not a clean-lifetime leak claim; the normal-lifetime weak-reference assertion passes.
- `CaptureMusicDrive`: 26 checks pass. Desktop: 15 peak voices, 118 us sampled / 693 us maximum mix, 512 frames at 48 kHz, zero render-budget overruns. Controller sample 34 us. Driving and Music Lab screenshots inspected; `CaptureMusic` passes but reports one pending ObjectDB instance at immediate screenshot exit.
- `ExportAndroid -QuickValidation`: import/startup, 74 driving, 18 catalog and 26 menu checks pass; APK export/signature verification succeeds. Full physics regressions were not run because handling is unchanged.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -TrackId track_1e3936d025fe7c82 -Baseline -Seconds 20 -ReportName music-rock-phone`: APK installed with existing user data preserved on attached DN2103, and a short synthetic-input driving run completed (176.597 m, median frame 16.634 ms, p95 20.529 ms). F8 enabled through ADB for evidence. [Phone screenshot](evidence/music-rock-phone/custom-phone.png) inspected: native engine v4, 45.72 beats advanced, 16 peak voices, zero audio render-budget overruns. Screenshot is paused after the run; its 10 us mix value is **not** active-DSP performance. No claim of OS-underrun detection or acoustic listening. Diagnostic markers removed and normal play relaunched; 10,000-lap probe setting was diagnostic only.

Desktop/build logs and screenshots: `docs/evidence/music-rock`; phone raw measurement/config/hash: `docs/evidence/music-rock-phone`. The APK includes the current shared workspace's existing visual changes; those unrelated edits are excluded from the music checkpoint.

Remaining acceptance: listen while driving Grass, especially riff fatigue, approach/release audibility, sound-effects balance and finish timing. Physical touch, speaker/headphone/Bluetooth quality, focus/resume, long-session audio glitches and thermal soak have not been tested for this revision. This is an approved direction for a trial, not a final score approval. Other biomes remain silent.

## Historical v1 verification (before the rock revision)

- Native `test_synth.cpp`: 60-second repeated seeded PCM equality, different-seed divergence, render allocation guard, finite/gain bounds, sample-clock duration, 32-voice cap, pause, finish decay, bar scheduling and hysteresis pass. Three simultaneous 60-second renders plus WAV output took 4.25 s on this desktop; this is an offline throughput measurement, not Android callback CPU. RMS .035289 and peak .154489 before the additional player gain.
- `dev.ps1 TestMusic`: 23 checks pass, including seed, metadata exclusion, geometry identity change, wrapping, seam continuity, curvature, lookahead, timestep-independent smoothing, BeatClock arithmetic, trajectory risks, physics immutability, real native stream telemetry and release of retired playback pools.
- `dev.ps1 CaptureMusicDrive`: 25 checks pass including real driving integration; final desktop screenshot inspected. Final six-second run: 24 peak voices; sampled mix 170 us, maximum 316 us, 512 frames / 48 kHz, zero callback render-budget overruns, sampled controller 34 us. These are short desktop observations, not a sustained worst-case guarantee.
- `dev.ps1 CaptureMusic`: graphical lab captured and inspected; final evidence is under `docs/evidence/music`.
- `dev.ps1 Validate -QuickValidation` and final `ExportAndroid -QuickValidation`: import/startup, 74 driving, 18 catalog, 26 menu checks pass. Final driving suite reported four ObjectDB instances at shutdown; focused music tests exit cleanly. Full physics regression was not run because canonical physics was not changed.
- Windows x86-64 and Android ARM64 debug/release native builds pass. Final Android debug export, signing and verification pass: `build/android/circuit01-debug.apk`. ZIP inspection confirms `lib/arm64-v8a/libbmt_music_v4.android.template_debug.arm64.so` and `assets/music/NOTICE.txt`. No device installation was performed for this slice.
- Initial export rejected the missing Android `lib` filename prefix; build/manifest corrected. Another preflight exposed an intermittent teardown access violation after driving assertions completed. Native playback now resolves lazy virtual dispatch on its creating thread before audio mixing. Twelve `TestMusicExit` process runs, each with 64 immediate create/play/free cycles and no grace delay, exit without crash. Abrupt stress-process exit still warns about 11–64 pending ObjectDB instances; the normal-lifetime test explicitly confirms all 16 playback weak references expire after mixer retirement. This distinction is retained rather than suppressing shutdown diagnostics.

An Android phone (ADB serial PRQKU4U4PREQNRWG) was attached. **No physical-device music listening, audio-glitch, thermal-soak, Bluetooth, focus/resume or CPU test was performed in this slice.** Render-budget overruns detect this callback exceeding its own block time; they cannot detect every OS/device underrun. No system-underrun count is exposed, so the overlay does not pretend to measure one.

Human acceptance remained: pluck identity, repeated-lap fatigue, audible approach/release, harmony/mix balance versus tyre/engine/UI sounds, finish timing, and mobile audio/performance. Also inspect branching/intersecting tracks, large tracks and aggressive braking/steering: the approximate trajectory predictor can overestimate risk. Grass is the only accepted-for-testing preset, not an approved final score. Phases 6–7 expansion waits for that listening review.
