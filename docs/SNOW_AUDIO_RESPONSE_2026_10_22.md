# Snow sound character and contact delay — 2026-10-22

SBR01–SBR04/R01/Q01 address the owner's rejection of the first snow sound and suspected collision delay. The revised snow uses a lower, softer compression attack and a denser, smoother scraping bed. Sound now follows the same 12-point current body envelope as the existing visible snow spray, including side panels that the previous seven-point physical sample could miss. It still reads the existing snowbank mesh; physical contacts, resistance, simulation state, rules and car/track geometry remain unchanged.

Three separate causes were reproduced:

- The snow entry was missing from the existing fast Windows event path and went through normal Godot/WASAPI output.
- The first recording's half-peak compression arrived 84.33 ms into the clip (peak 92.15 ms); the revised half-peak arrives at 0.59 ms.
- Visible side-panel snow contact could precede every physical wheel/centre/bumper sample. The preserved mixer fails both onset and sustained panel-contact checks for all five cars.

The native adapter now preloads five samples, with the same four shared event slots. Snow observes Vehicle gain/mute alongside chassis; crashes retain Impacts routing. One playback path is selected per event. A versioned v5 DLL avoids replacing binaries held by a running editor/client. If an older four-clip DLL is still loaded during script reload, its original crash/chassis route remains operational and only unsupported snow falls back. A complete client restart loads v5. Other platforms retain normal Godot playback.

## Actual Windows output timing

The same diagnostic emitted three trials per cue before and after. The helper captured only that diagnostic process tree, using timestamped WASAPI process-loopback packets. No microphone, system-wide audio or other application audio was recorded. No fixed capture offset was subtracted.

| Cue | Before median | After median |
| --- | ---: | ---: |
| Snow entry | 152.25 ms | 47.08 ms |
| Light crash | 52.45 ms | 47.99 ms |
| Medium crash | 47.45 ms | 49.99 ms |
| Heavy crash | 49.45 ms | 48.99 ms |
| Chassis/kerb-entry/bridge/landing sample | 50.85 ms | 49.39 ms |

Snow changes from the Godot route to the native route in all three trials; the existing four cues already use the native route. Their small before/after differences are not claimed as improvements. The driver's reported 10 ms is not the measured output delay. These measurements stop before physical speakers/headphones/Bluetooth; the owner's audio setup was asked via the pending optional question and is not assumed to match the test device. Physical-device listening and the preferred sound character/level remain owner acceptance.

The visible-wall regression confirms first visible-contact dispatch, with at most one 120 Hz tick in its sampled cases, and an actual Game callback at visual/sound tick 63 versus canonical response tick 81. The canonical circle's later contact is not used to delay that cue. The exact timing and separate ordinary contact sounds remain in [the evidence report](evidence/snow-audio-response-2026-10-22/report.json).

## Sound and changed files

`scripts/build_snow_audio.py` now uses only the existing two cleared soft-snow recordings for its cyclic bed, with dense 35–70 ms overlap, 150 ms cyclic energy control and 85–3000 Hz shaping. The entry uses the same cleared recorded compression, slowed and trimmed to the actual attack, with 85–2600 Hz shaping and a short tail. No generated tones/noise, new recording downloads or runtime dependencies are added. Source and derivative identities remain in `game/assets/audio/vehicles/snow_manifest.json` revision 2. The previous sources/assets are retained under this task's `before/` evidence.

- Presentation: `game/vehicle/{surface_audio_model,vehicle_audio}.gd`, `game/platform/windows_impact_audio.gd`.
- Native output: `native/windows_audio/impact.cpp`, `scripts/build_windows_audio.ps1`, `game/platform/windows/{impact.gdextension,bmt_windows_audio_v5.dll,NOTICE.txt}`. Existing Godot bindings/MinGW/runtime notices remain. Built and shipped DLL hashes both equal `66062E95C766B88FD9B91A06581E3D3949DC5A1847D64B824B319C20028997FA`; no existing DLL is deleted. The existing Android `platform/windows/*` exclusion covers v5.
- Snow assets/provenance: `snow.wav`, `snow_hit.wav`, `snow_manifest.json`, vehicle `NOTICE.txt`, `licenses/ASSETS.md`.
- Tests/diagnostics: `test_snow_audio_response.gd`, `probe_contact_audio_output.gd`, `capture_snow_audio_response.gd` and UIDs; five-sample inventory/bounds in `test_windows_impact_audio.gd`; `scripts/{probe_contact_audio_output.ps1,review_snow_response.py}`. Existing process-loopback helper and reviewer are reused.
- This report, project status/plan and the scoped AGENTS entry. Concurrent kerb, graphics, bridge and other changes remain preserved.

## Commands and results

Engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and the pinned `4.7.2.stable.official.ed1daf0bf` build. Actual commands/selected logs and source hashes are in the evidence report.

| Command / check | Result |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/probe_contact_audio_output.ps1 -Phase before` | 15 before events captured. The first launcher lost its process handle when reading ExitCode after exit; retained audio/events and clean engine completion were reviewed with `python scripts/review_windows_audio_output.py build/snow-audio-response-2026-10-22/before`. |
| `python scripts/build_snow_audio.py` | Revised clips/manifest built; strong entry attack 0.59 ms; cyclic endpoint step zero. |
| `... -Action BuildWindowsAudio` | v5 built; installed binary matches exact build output. |
| `... -Action Import` | Revised clips and native adapter pass import. |
| `test_snow_audio_response.gd -TestArgument --baseline` | Preserved previous mixer/entry reproduce 11 failures in 27 checks. All assertions retained. |
| `test_snow_audio_response.gd` headless / native Compatibility | 29 / 35 checks, zero failures. Covers visible panels for all cars, shared contacts, sample attack, fast route/no duplicate, four-slot bound, reset and native/older-DLL fallbacks. |
| `test_snow_bank_audio.gd` | 89 headless checks, zero failures; actual physical crossings remain byte-exact. |
| `test_windows_impact_audio.gd` / `test_collision_attack.gd`, native Compatibility | 18 / 22 checks, zero failures. Invalid index remains rejected; inventory now includes the valid fifth snow clip. |
| `test_visible_wall_audio.gd` / `test_bridge_contact_audio.gd` | 167 / 42,184 headless checks, zero failures. |
| `test_script_parse.gd` | 933 scripts, zero failures at the recorded scan. |
| `.../scripts/probe_contact_audio_output.ps1 -Phase after` | 15 after events captured/reviewed successfully with the retained process-handle correction. |
| `capture_snow_audio_response.gd`, native Compatibility | Six checks, zero failures. Separate master/snow/unwanted-bus tone auditions preserve the first iteration's files. |
| `python scripts/review_snow_response.py` | Ten captured-output/attack/audition checks, zero failures. |
| Scoped whitespace and task-patch reverse checks | Recorded in the evidence report. |

One existing Compact cooldown-fixture assertion in `test_contact_escalation_audio.gd` fails (65 checks / 1 failure). Running that exact suite with only `VehicleAudio.new()` replaced by a loader for the task-start mixer reproduces the same failure and identical contact rows. Its ten driving scenarios still dispatch on their first eligible tick with exact states. The original-code test entry is retained as `original-contact-regression.gd.txt`; its temporary executable copy was removed. No assertion was removed or relaxed, and this separate fixture is not reported as passing.

## Review and limits

[Revised game mix](evidence/snow-audio-response-2026-10-22/audition/driving.wav), [snow alone](evidence/snow-audio-response-2026-10-22/audition/snow.wav), [before/after listening page](evidence/snow-audio-response-2026-10-22/review.html). Tone auditions deliberately use the ordinary Godot buses so their stems can be recorded; separate timestamped process captures verify actual native output latency. No acoustic or Bluetooth latency claim is made.

Complete client restart and owner listening remain. No phone attachment check/device test, APK action, live account/backend mutation or deployment was performed. No running owner editor/client was terminated. The task patch is scoped against saved task-start sources, with only this task's documentation additions; the shared dirty Git index is not committed.
