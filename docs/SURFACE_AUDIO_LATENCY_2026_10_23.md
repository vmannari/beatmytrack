# Shared driving-sound latency - 2026-10-23

SAL01-SAL03/R01/Q01 address the owner's report that kerbs and many other driving sounds arrive late. Kerb rolling now starts in the actual resolved-contact physics callback, using its existing contact/speed gain and pitch. The original entry bump, swept crossings, render holds, recordings and canonical driving remain intact.

The larger measured delay was shared by normal Godot/WASAPI playback. The previous native adapter accelerated crashes, chassis and snow entry, while engine, continuous surfaces and ordinary debris still used the normal Windows stream. One app-owned native output now transfers the finished Godot stereo mix to RAW GameEffects WASAPI. Existing streams, mixing, compressor, limiters and bus gains still run in Godot. The Master fader/mute is applied exactly once at the sink because it follows effects in Godot. The original four-slot/five-sample native event renderer remains unchanged.

## Actual Windows output measurements

The diagnostic raises the existing kerb, grass, scrape, water, debris and engine streams three times each. The existing process-loopback helper captures only that diagnostic process tree, with valid WASAPI timestamps. No microphone, other application audio or fixed latency subtraction is involved. This measures a requested gain/event change to audible Windows output; physical speakers, headphones, Bluetooth and input/contact detection are outside this measurement.

| Existing sound | Before median | Final median |
| --- | ---: | ---: |
| Kerb rolling | 146.28 ms | 54.65 ms |
| Grass | 145.60 ms | 52.38 ms |
| Barrier scrape | 144.22 ms | 54.96 ms |
| Water spray | 148.24 ms | 53.05 ms |
| Ordinary debris | 142.30 ms | 52.82 ms |
| Engine change | 142.33 ms | 55.55 ms |
| All 18 requests | 144.86 ms | 53.04 ms |

The before range is 139.64-153.03 ms; final output is 50.05-59.92 ms. The first revised pass measured 60.35 ms median, consistent with mix-phase/scheduling variation; only its summary and the final pass's complete raw capture are retained. Driver-reported latency remains 10 ms and is not used as the actual result. The final timing/control captures and hashes are under [the evidence report](evidence/surface-audio-latency-2026-10-23/report.json).

## Bounds and compatibility

One 4096-frame/32 KiB stereo ring connects the Godot mixer thread to the native output worker. The callback performs no allocation, decoding or mutex locking. At most one native period is queued to WASAPI. Two minutes of five-car sustained playback render 5,291,520 frames with zero overflows and a peak ring occupancy of 960 frames. Reset/pause, retry, race teardown and app shutdown remain covered by the original suites and focused route checks.

Only Windows WASAPI, Default output, stereo and matching device/source sample rates with RAW support use the transfer. Other platforms, headless verification, older loaded DLLs, custom outputs, unsupported formats and unavailable devices retain ordinary Godot output. A full ring fails open to that route instead of growing a queue. Native failures/device changes stop taking PCM; the normal route remains available. Physical unplug/replug and device switching were not exercised. Windows optional output processing is bypassed, as with the existing native impact path. Captured fallback audio matches a separate original Godot-output reference; it includes that route's OS processing.

The app owns the sink across races. Diagnostic Master recorders must call `windows_output.sync_output()` after insertion and before activating recording, so the transfer is last before Godot creates active recording state. Adjacent swaps preserve the relative order of existing effects. Recorders remove their own effect by identity. No production diagnostic recorder is installed.

The final DLL is `game/platform/windows/bmt_windows_audio_v6.1f55238709ec.dll`, SHA-256 `1F55238709EC1F352E98153E21148C5920EE6BB2F8B5D5200484B12CD90C4F0B`. It uses the existing pinned MIT Godot bindings and installed MinGW runtimes, with the supplied notices. No new package, SDK, media or runtime service was added. The build now selects a content-addressed filename so a running editor's library is never overwritten. The initial v6 prototype remains locally because an existing process holds it; the runtime manifest and scoped checkpoint select only the final file.

## Changes and validation

- Runtime: `game/platform/windows_audio_output.gd`, `game/soundtrack/audio_world.gd`, `game/vehicle/vehicle_audio.gd`; native `mix_output.h`, registration, binding profile/build helper, build script, extension manifest and final DLL.
- Diagnostics: `test_surface_audio_response.gd`, surface/mixed-output probes, capture launcher and mixed-output reviewer. Existing vehicle/kerb recorders now synchronize placement and remove their own effect; the continuity suite also checks native sink health per car.
- An existing compressed-texture setting exposed a static `get_pixel()` startup error after the content import refreshed. `NativeTrackVisual._desert_road_reference()` now decompresses its local CPU image before reading it. Concurrent graphics work added the same guard while this task ran; the duplicate was removed and its single final copy is retained as that work's effective baseline. Texture imports/GPU assets and the concurrent rendering implementation are preserved. A concurrent rendering fixture also needed an explicit test-local `NightRenderPreparation` preload; its assertions remain intact.
- Provenance/status: Windows NOTICE, asset register, this document, AGENTS, development status/plan, evidence and task-only Git patch.

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned `4.7.2.stable.official.ed1daf0bf`. Full command variants and selected logs are retained in the report.

| Actual check | Outcome |
| --- | --- |
| `BuildWindowsAudio` and built/shipped hash/import inspection | Final binaries match; Windows system DLL imports only. |
| `scripts/probe_surface_audio_output.ps1 -Phase before` / `-Phase after` | 18 requests each; measured table above. |
| `scripts/probe_surface_audio_output.ps1 -Controls` | Six engine lifecycle assertions and 45 captured-output checks pass: Master/Vehicle/Tires half gain, all bus mutes, explicit solo send chain, stereo frequencies/amplitudes, no duplicate copy, original fallback and restoration, sustained mix, unsupported rate and close/reopen. |
| `test_surface_audio_response.gd -TestArgument --baseline` | Preserved mixer reproduces five first-physics failures in 26 checks, one per car. |
| Same focused test, headless / native Compatibility / desktop Mobile | 26 / 36 / 36 checks, zero failures. |
| Native `test_vehicle_audio.gd` / `test_grass_kerb_audio.gd` | 1469 / 88 checks, zero failures, including actual Game contacts and native recordings. |
| Native `test_vehicle_audio_continuity.gd` | 53 checks, zero failures; all six engine layers wrap multiple times for all five cars. |
| Native Windows impacts / collision attack / snow response | 18 / 22 / 35 checks, zero failures. |
| Headless snowbank / audio loops / soundtrack lifecycle | 89 / 208 / 1158 checks, zero failures. |
| `TestWindowsAudioExport` plus ZIP inventory | 4041 content entries, no Windows adapter; content ZIP only, no APK. |
| Final import / parser | Import passes; 990 scripts, zero failures. |
| Scoped Git checks | Actual receipts are in checkpoint.json. |

Initial failures remain documented: the focused fixture reused an inherited constant name; a continuity test was mistakenly invoked headlessly; the first control capture had a timestamp gap, a Tires-only solo fixture produced silence already in the upstream Godot recording, and fallback was incorrectly compared to RAW rather than original processed output. The corrected fixtures retain the gain/silence/no-duplicate invariants and add a separately measured normal-output reference. The first integrated recorder was moved after recording began and lost its instance; explicit synchronization fixes that lifecycle. The compressed-image startup failure and the concurrent fixture's missing preload are retained with their correction receipts; import alone did not resolve that non-global script reference. No failing assertion was hidden or weakened.

## Remaining acceptance

A complete client restart is required; no running owner editor/game was terminated. Owner listening on the actual audio setup and physical-device latency/long-session/device-switch acceptance remain. The Windows improvement is not an Android or acoustic latency certification. No phone attachment check/device test, APK action, account/backend mutation or deployment was performed. The scoped checkpoint is based on saved task-start/current shared-document bases, preserving concurrent work without committing the shared index.
