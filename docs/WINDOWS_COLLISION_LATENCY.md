# Windows collision playback latency — 2026-10-09

The owner still hears approximately 100 ms of collision delay on **Windows with
both Bluetooth and connected speakers**. SND16 requires measuring the output
path rather than treating Godot's reported latency as the audible delay. SND17
requires reducing that delay while retaining SND05/SND08/SND11/SND14/SND15,
G01/R01/Q01/V06: immediate visible-contact dispatch, pause/countdown/rewind
guards, volume/mute, bounded voices, protected output and canonical separation.

An isolated collision request reached Windows process-loopback **130.32–144.32
ms** later, median **138.16 ms**, although `AudioServer.get_output_latency()`
reported 10 ms. Requesting 3 ms instead of the default 15 ms did not help:
WASAPI reported minimum/fundamental/maximum periods of 480 frames at 48 kHz,
and the measured median was **143.56 ms**. No ineffective 3 ms production setting
was retained.

The new Windows presentation adapter requests a shared-mode **RAW GameEffects**
stream and keeps at most **one supported period** queued. The recorded samples
are already loaded; the real physics callback starts a native voice directly.
Godot's delayed copy is suppressed. Four native slots share the existing four
body-event slots with chassis sounds, preserving the 22 simultaneous vehicle
voice bound. Reset clears tails, pause freezes them, Vehicle/Impacts and Master
volume/mute/solo are observed, and individual -2/-1 dB ceilings remain. Default
device notifications reopen the stream. Unsupported output/RAW/format, custom
Godot output devices, headless servers and the Android export use normal Godot
playback. No Windows system settings, running owner game/editor or preferences
were changed or forcibly closed.

The exact pinned Godot **4.7.2.stable.official.ed1daf0bf** remains unchanged. The
adapter reuses the existing cleared `godot-cpp` 4.5 ABI revision
`e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77` and installed MinGW compiler; no new
SDK/package/runtime service was downloaded. The reproducible 1,470,270-byte DLL
has SHA-256 **CC10E916CA523F491F8CC9B818DB4E1A80C1252A962262C43937F467B8842822**
and imports only AVRT/KERNEL32/msvcrt/ole32 Windows libraries. Bundled notices
cover the existing static bindings/compiler/thread runtimes. Engine, sand,
grass, music and sample masters were not revised by this task.

## Actual measurements and their limits

[Captured before/after audio and waveform](evidence/windows-audio-latency-2026-10-09/audition.html).

| Own-process Windows test | Median | Range |
| --- | ---: | ---: |
| Before: normal Godot collision, requested 15 ms | 138.16 ms | 130.32–144.32 ms |
| Normal Godot, requested 3 ms | 143.56 ms | 134.40–146.56 ms |
| Native calibration, normal processing/minimum period | 111.32 ms | 110.64–112.92 ms |
| Native calibration, RAW/minimum period | 52.97 ms | 51.90–53.53 ms |
| New direct collision request | 41.71 ms | 37.71–46.71 ms |
| Final DLL, actual Game wall callback | **43.95 ms** | **38.95–45.95 ms** |

Each row contains six trials. The actual Game callback still reports visible
contact/sound tick **62**, canonical physical response tick **81**, exactly one
cue and unchanged canonical results. Rendering was disabled in this controlled
callback test; it tests the shipping callback, not a human driving session.

The calibration also records the independent WASAPI render clock: normal and
RAW both put the pulse at roughly 29–31 ms on that clock, while their captured
waveforms differ substantially. RAW process-loopback is about 17–23 ms after
that clock in the retained comparisons. Therefore these are **process-output
measurements**, not exact speaker/headphone acoustic latency. No fixed capture
offset is subtracted and no zero-acoustic claim is made. The relative reduction
is supported by identical capture machinery. Optional Windows processing is
the inferred cause of the substantial normal-versus-RAW difference; hardware
and Bluetooth may add further delay after this measurement point.

The helper explicitly captures only the diagnostic PID/process tree. It never
opens a microphone or falls back to recording unrelated applications. Invalid
packet timestamps and audible pre-trigger contamination are rejected. One
initial Game-wall capture contained startup music/chassis output and is marked
rejected; the final wall run mutes other buses and passes the quiet pre-trigger
check. Its native collision remains audible.

Final captured controls verify 30% Vehicle gain, Vehicle/Master mute,
pause/countdown silence, three overlapping impacts and an actual engine/impact
mix: **9 checks, 0 failures**. The overlap ceiling and zero full-scale samples
are checked on the captured output. This is the tested mixture, not a proof for
every possible maximum-volume music/vehicle combination; native impact and
normal Godot output are combined by the Windows mixer.

## Files and actual commands

- Runtime: `game/vehicle/vehicle_audio.gd`,
  `game/platform/windows_impact_audio.gd`, `native/windows_audio/impact.cpp`,
  `game/platform/windows/impact.gdextension`, versioned DLL and license notices.
- Build/platform boundary: `scripts/build_windows_audio.ps1`, `scripts/dev.ps1`,
  `game/export_presets.cfg`. The local Android content ZIP contains **1,220
  files/73,532,139 bytes**, **zero Windows binaries/extensions**; three exclusion
  checks pass. There is no Windows extension list in that export.
- Output diagnostics: `scripts/windows_process_audio_probe.cs`,
  `scripts/windows_native_audio_pulse.cs`, `scripts/review_windows_audio_output.py`,
  `scripts/review_windows_impact_controls.py`,
  `scripts/review_windows_audio_export.py`,
  `game/tests/probe_windows_audio_output.gd`,
  `game/tests/capture_windows_impact_controls.gd`,
  `game/tests/test_windows_impact_audio.gd` and generated UIDs.
- Existing Godot bus diagnostics explicitly select the fallback path:
  `test_effect_timing.gd`, `test_collision_attack.gd`,
  `capture_effect_timing.gd`, `capture_collision_attack.gd`.
- Records/provenance: this document, `DEVELOPMENT_STATUS.md`,
  `docs/PHASE_0_PLAN.md`, `licenses/ASSETS.md`, retained evidence/checkpoint.

Actual entry-point commands, always using `powershell -NoProfile
-ExecutionPolicy Bypass -File scripts/dev.ps1`:

```powershell
BuildWindowsAudio
Import
TestScript -ScriptPath res://tests/probe_windows_audio_output.gd -Graphical
TestScript -ScriptPath res://tests/probe_windows_audio_output.gd -Graphical -AudioLatencyMs 3 -EngineVerbose
TestScript -ScriptPath res://tests/probe_windows_audio_output.gd -Graphical -TestArgument '--wall'
TestScript -ScriptPath res://tests/capture_windows_impact_controls.gd -Graphical
TestScript -ScriptPath res://tests/test_windows_impact_audio.gd -Graphical
TestScript -ScriptPath res://tests/test_windows_impact_audio.gd
TestScript -ScriptPath res://tests/test_effect_timing.gd
TestScript -ScriptPath res://tests/test_effect_timing.gd -Graphical
TestScript -ScriptPath res://tests/test_collision_attack.gd
TestScript -ScriptPath res://tests/test_visible_wall_audio.gd
TestScript -ScriptPath res://tests/test_vehicle_audio.gd
TestScript -ScriptPath res://tests/test_continuous_desert_audio.gd
TestScript -ScriptPath res://tests/test_script_parse.gd
TestApp
TestRewind
TestWindowsAudioExport
```

The C# helper was compiled with installed Framework64 `csc.exe /platform:x64`,
both diagnostic source files and absolute output/source paths. It was invoked
with the PID from `ready.json`, output directory and 12-second capture duration;
calibrations used `self`, `self-raw`, `self-fast`, `self-raw-fast` for 10/12
seconds. Reviews ran with Python/NumPy using the three review scripts above.

Final focused results: Windows graphical **16**, headless fallback **2**,
Godot attack **22**, timing **43** (also graphical), visible wall **167**,
vehicle **1,442**, continuous desert **28**, App **99**, rewind **57** and parser
**394** checks pass. The attack test retains an **83 ObjectDB shutdown-reference
warning**; the final native Windows lifecycle test exits cleanly. Two consecutive
final native builds produce the exact same hash. No failing assertion was
removed or relaxed. Initial compiler GUID-link error, activation/apartment
errors, capture-arm timeouts, shell quoting errors and locked intermediate DLL
attempts were corrected/retained. Locked intermediate binaries are ignored and
superseded by the final version; the owner's editor was not killed.

Evidence is under `docs/evidence/windows-audio-latency-2026-10-09/` with raw
process captures, packet/event/clock metadata, reports, selected actual logs,
source hashes and a scoped review patch. The checkpoint contains 36 scoped files
and 15 selected native logs; its Git reverse-apply check passes without changing
the shared index. Large scratch/calibration alternatives remain under ignored
`build/audio-output-2026-10-09/`. No UI changed, so no new
screenshot is required.

## Acceptance still needed

Restart the Windows game to load the new native library, then listen while
driving into walls using connected speakers and Bluetooth. Actual default-device
switching, uncommon Windows output formats and Bluetooth hardware latency need
owner/device acceptance. No phone attachment check, physical Android audio test,
APK export/install, full Validate, physics merge, backend change or production
deployment was performed. Canonical simulation/rules/handling have no task
changes; exact wall snapshots remain covered by the existing observer test.

Primary implementation references:
[Godot WASAPI source](https://github.com/godotengine/godot/blob/master/drivers/wasapi/audio_driver_wasapi.cpp),
[Microsoft RAW stream options](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/ne-audioclient-audclnt_streamoptions),
[Microsoft process-loopback sample](https://learn.microsoft.com/en-us/samples/microsoft/windows-classic-samples/applicationloopbackaudio-sample/),
[Microsoft render clock](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudioclock-getposition).
