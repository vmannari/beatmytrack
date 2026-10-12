# Shared Windows body-sound timing — 2026-10-09

The owner reports the direct-collision issue **on every track**. SND-WB01 fixes
the remaining shared body-sound route and idle buffering, preserving
SND05/SND14–SND18/SND-DC01/G01/R01/Q01/V06: unchanged physics and recorded assets,
bounded voices, direct event dispatch, bus controls, pause/reset/rewind and
protected output. This is not a track-specific timing adjustment.

The main impact already used Windows RAW, but **chassis/body thuds still used
ordinary Godot playback**. A paired capture using the same process, device,
input sample bank and clock measured:

| Sound | Before median/range | After median/range |
| --- | ---: | ---: |
| Main impact | 41.24 / 37.24–43.24 ms | **35.08 / 32.08–39.08 ms** |
| Chassis/body thud | 146.26 / 145.93–150.60 ms | **35.56 / 31.56–38.56 ms** |

Each row has three trials. These are own-process digital output timings, not
exact speaker/Bluetooth acoustic timings. They include the process-capture
path; no fixed offset is subtracted. The source samples themselves remain
unchanged and start promptly. The large extra delay in the body-thud route is
reproduced, while the owner's particular perceived sound still requires listening.

A real Game callback at 108 km/h and 45 degrees into a wall produces the main
impact on tick18, physical response on21 and a downshift/body thud on44. This is
a **hard direct impact, not a shallow scrape**. Its thud therefore also inherited
the slower output route. A centered head-on fixture did not produce that extra
thud; the first corresponding assertion failed and was retained. The successful
angled fixture is not presented as proof that every centered impact emits it.
The existing drivetrain scheduling is unchanged; the fix removes the extra
output-path delay after each body event is requested.

All four collision/body PCM clips (three severity hits plus chassis) now share
the native output and **the same four event slots**. Chassis still follows
**Vehicle**, impacts still follow **Impacts**, and both follow Master. Separate
mute/solo/gain controls preserve their original routing roles. Native impact and
chassis sums retain -2 dB per-group protection and a combined -1 dB ceiling.
Ordinary Vehicle compression is not applied to native chassis; the paired gear
thud is below its -10 dB threshold. Higher-amplitude landing/kerb texture still
needs owner listening acceptance. Engine, tires, debris, music and samples are
not rerouted or remastered by this task.

The native stream also stops writing **idle silent packets**. It stays open in
shared RAW mode but lets its queue drain when no voice is active, so a new impact
does not wait behind deliberately queued silence. Active output keeps at most
one supported period; mute consumes active tails and pause freezes them as
before. Four voices/two debris voices and the 22 simultaneous vehicle voice
bound remain. Device-change handling and unavailable/unsupported/custom-device
Godot fallback remain.

## Actual evidence and checks

The pinned engine remains **4.7.2.stable.official.ed1daf0bf**. Existing cleared
godot-cpp revision `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77` and installed
MinGW build `bmt_windows_audio_v3.dll`, **1,478,013 bytes**, SHA-256
**B01F6479DCFEF435B95390B6B8F2491F6510917E350A723AF8097ABB2AC8570E**.
Two builds yield the same hash. Its imported DLLs are Windows system
AVRT/KERNEL32/msvcrt/ole32 only. No new SDK/package was downloaded. Previous
binaries are preserved/ignored because running owner processes may hold them;
no owner game/editor was killed to replace a locked DLL.

Updated real-time head-on Game/rendering trials at 18/54/108 km/h show one primary
cue and actual RAW output on every hit: **30.39–38.39 ms** cue-to-software-output.
Normal rendered-footprint-to-output is **22.39–25.39 ms**. The deliberate
canonical-only controls remain clearly marked and are not production changes.
Thirty timeline/route checks pass. Current per-row native submissions may include
muted chassis events during warm-up; the primary cue count stays one.

Eleven paired-output/control checks pass: approximately 30% Vehicle gain,
Vehicle/Master mute and pause silence, chassis audible despite Impacts mute,
primary impact audible despite direct Vehicle mute, four overlapping bodies
and no full-scale clipping. The captured overlap peak is 0.89127, within the
retained -1 dB ceiling at 16-bit rounding precision.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1`:

```powershell
BuildWindowsAudio
TestScript -ScriptPath res://tests/probe_shared_collision_audio.gd -Graphical
TestScript -ScriptPath res://tests/probe_shared_collision_audio.gd -Graphical -TestArgument '--audio-probe-output=res://../build/shared-collision-audio-2026-10-09/after'
TestScript -ScriptPath res://tests/capture_shared_body_controls.gd -Graphical
TestScript -ScriptPath res://tests/probe_direct_collision_output.gd -Graphical
TestScript -ScriptPath res://tests/test_windows_impact_audio.gd -Graphical
TestScript -ScriptPath res://tests/test_direct_hit_body_audio.gd
TestScript -ScriptPath res://tests/test_effect_timing.gd
TestScript -ScriptPath res://tests/test_contact_escalation_audio.gd
TestApp
TestRewind
TestScript -ScriptPath res://tests/test_script_parse.gd
TestWindowsAudioExport
```

Existing own-PID process-loopback helper captures use PID from each `ready.json`
for12 seconds (paired/controls) or25 seconds (real-time direct hits). Python
reviews: `scripts/review_windows_audio_output.py`,
`scripts/review_shared_body_audio.py`, `scripts/review_direct_collision_output.py`
and `scripts/review_windows_audio_export.py`. Review rejects invalid timestamps
or audible pre-trigger contamination. No microphone/other-app recording.

Final focused outcomes: actual Windows backend **18**, direct-body event **5**,
timing **43**, contact escalation **65**, App **99**, rewind **61**, parser **418**
checks pass. Timing retains a **31 ObjectDB shutdown-reference warning**. The
centered-thud fixture assumption failed initially; corrected 45-degree fixture
keeps every assertion and passes. The primary centered collision timeline remains
separately tested. No failed invariant was removed or weakened.

After focused checks, the actual Android **content ZIP only** contains
**1,236 files/77,399,496 bytes** and zero Windows DLLs/extensions; three exclusion
checks pass. No APK export/install or physical Android audio test was performed.

## Scope and acceptance

Runtime/build: `native/windows_audio/impact.cpp`,
`game/platform/windows_impact_audio.gd`, `game/vehicle/vehicle_audio.gd`,
`game/platform/windows/impact.gdextension`, versioned DLL/ignore/notice,
`scripts/build_windows_audio.ps1`. Diagnostics:
`probe_shared_collision_audio.gd`, `capture_shared_body_controls.gd`,
`test_direct_hit_body_audio.gd` and UIDs, revised
`test_windows_impact_audio.gd`, `scripts/review_shared_body_audio.py`.
Records: this note, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`,
`licenses/ASSETS.md` and task-only evidence/checkpoint under
`docs/evidence/shared-body-audio-2026-10-09/`.

The native PCM clip contract expands from3 to4; the invalid-index check now uses4
and explicitly verifies clip count and four shared slots. This updates that
contract rather than dropping out-of-range protection. All 47 vehicle WAVs still
match their manifest; no canonical/rules/track schema or fixture contract changes.

**Restart the Windows game** to load v3, then test direct hits on the usual
tracks with connected speakers and Bluetooth. Owner perception, physical
speaker/headphone latency, uncommon device switching/format behavior and louder
landing texture remain acceptance checks. No phone attachment check, microphone
or new acoustic measurement, physical Android test, full Validate, physics merge,
backend change or deployment was performed. No ordinary UI changed.
