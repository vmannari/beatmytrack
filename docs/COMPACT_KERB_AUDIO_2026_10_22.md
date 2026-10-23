# Compact kerb audio — 2026-10-22

Owner feedback: driving over kerbs sounds too muted in the Compact.
CKA01/CKA02 refine SND53 with G01/R01/Q01 presentation separation.

`game/vehicle/vehicle_audio.gd` now raises the Compact's existing kerb thud loop
by **4.5 dB** and its actual entry chassis bump by **3 dB**. The gain is selected
by the configured vehicle identity. Other vehicles retain their original mix.
The existing thud asset, pitch/rhythm, wheel contact/sweep, 40 ms hold, silence
gates, Desert exclusion, voice/cache bounds and canonical driving remain intact.
The existing concurrent bridge-landing feedback change is preserved.

Pinned Godot: `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`.
Successful runs use task-specific `APPDATA` beneath
`build/compact-kerb-audio-2026-10-22/`, without owner account/save changes.

Actual commands and outcomes:

| Command | Outcome |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_kerb_audio.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-dir=res://../docs/evidence/compact-kerb-audio-2026-10-22/before-approved' -CommandTimeoutSeconds 180` | Original: **88 checks, zero failures**, 12 native recordings. |
| Same command, evidence directory ending `/after` | Adjusted: **88 checks, zero failures**, 12 native recordings. Includes all five cars, contact gates, canonical snapshot equivalence and the actual Game callback. |
| `... -Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd -Graphical -RenderingMethod gl_compatibility` | Final: **1,469 checks, zero failures**. |
| `... -Action TestScript -ScriptPath res://tests/test_desert_soft_sand_audio.gd` | **67 checks, zero failures**. |
| `... -Action TestScript -ScriptPath res://tests/test_bridge_contact_audio.gd` | **42,184 checks, zero failures**; original real-bridge cues, contact identities and silence fences retained. |
| `... -Action CheckScript -ScriptPath res://vehicle/vehicle_audio.gd` | Exit 0. |
| `python build/review_compact_kerb_audio.py` | **24 captures pass**; isolated kerb peaks increase 4.5 dB, silent pause tails and no false kerb on grass. Both original runtime asset hashes match. |
| `git diff --check -- game/vehicle/vehicle_audio.gd` | Exit 0; routine existing CRLF normalization notice only. |
| `git apply --check --reverse docs/evidence/compact-kerb-audio-2026-10-22/task-only.patch` | Exit 0 against the final working tree. |

The adjusted mixed crossing/riding/three-speed peaks are 0.4721/0.6124/0.7735
(highest about −2.23 dBFS), with no clipped samples. The actual Game crossing
still gives two entry bumps and no physical crashes; its maximum loop gain
changes from 0.6012 to 1.0093, exactly the requested multiplier. A player gain
above one is supported and is not a PCM clipping measurement.

Initial attempts are retained separately: sandbox runs hit Windows log/certificate
permissions; a local import attempt failed copying an in-use native geometry DLL.
The broad audio test in headless mode completed 1,454 checks with its one
`pause suspends loop playback` failure, because headless mode does not start audio
streams. Initial graphical retries encountered concurrent new ambience class/cache
and constant-expression parse errors. Their code/assertions were not changed here.
After that separate work settled, the full graphical audio and headless bridge
regressions above passed. No failed assertions were removed or weakened.

Evidence: `docs/evidence/compact-kerb-audio-2026-10-22/`, including before/after
WAVs, digital review, actual logs and a task-only runtime patch against the saved
working-tree source. The shared Git index is untouched. No new test assertions,
audio assets, physics/rules/schema changes or dependencies were introduced.
Changed documentation: this receipt, `DEVELOPMENT_STATUS.md` and
`docs/PHASE_0_PLAN.md`. The task-only patch includes those documentation changes;
`checkpoint.json` records their final hashes alongside the runtime source.

Remaining acceptance: restart/update the local client and listen while driving
actual kerbs, especially through phone speakers/headphones. Recordings use
controlled contact poses and a coasting engine at 5/18/36 m/s; they are desktop
digital measurements, not a complete-race or physical-device listening result.
No phone attachment check/device test, APK/export/install, backend/account mutation
or deployment was performed.
