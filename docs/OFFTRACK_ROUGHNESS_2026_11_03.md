# More uneven off-track response - 2026-11-03

OTR01: Make off-track driving more uneven than the November 2 profile. OTR02: Retain protected surfaces, per-wheel response, deterministic presentation and the existing smoothness limits. R01/Q01: Native visual evidence and a task-only review checkpoint.

`game/track/native_track.gd` raises broad wave amplitudes from 120/75 mm to 140/80 mm, adds a 30 mm cross-wave with an approximately 5.3 m wavelength, and raises the fine irregularities from 12/8 mm to 18/12 mm. This gives stronger rises/dips and more independent axle/side movement. These are sampled presentation heights for wheel/body suspension; the rendered terrain mesh is unchanged. Canonical handling, collision, road/kerb geometry, timing and competitive identities are unchanged.

`game/tests/test_offtrack_roughness.gd` compares two actual Compact spring responses against identical trajectories at 5, 12 and 22 m/s in four headings. Its control is the exact immediately previous profile. Across those twelve paths, body heave span increases 10.2-16.7%; the combined pitch/roll span increases 18.3-57.5%. At 12 m/s, body heave span is 0.368-0.424 m. Existing historical broad-profile gates are retained, including less than 12 mm heave change per tick, less than 240 mm absolute body heave, and more than 65% slow-travel dominance. Grass and loose soil agree; all protected surface exclusions, airborne/bridge/roll/stationary/hover exclusions, per-wheel contacts and road settling pass. These are measured staged paths, not a universal maximum.

| Actual command target | Result |
| --- | --- |
| `test_offtrack_roughness.gd`, headless | 91 checks, 0 failures |
| Unchanged `test_off_road_suspension.gd`, headless | 13 checks, 0 failures |
| Unchanged `test_suspension.gd`, headless | 59 checks, 0 failures |
| `test_offtrack_roughness.gd -- --capture`, native Compatibility | 152 checks, 0 failures; 61 frames |
| Same, native desktop Mobile | 152 checks, 0 failures; 61 frames |

Successful commands ran from the repository root using the pinned Godot 4.7.2 standard console executable and the required crash-dialog wrapper. Process-local APPDATA and LOCALAPPDATA pointed to absolute workspace directories under `build/offtrack-roughness/`, isolating the owner's saves. The known root-certificate-store warning appears in each test log; these fixtures perform no network operations. All five final process exit codes are zero. An initial source-edit script stopped before changes because its Unicode comment match failed through PowerShell; the subsequent attempted test reported a missing file. ASCII-only matching corrected the edit before the successful runs. No failing test gate was changed.

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/offtrack-roughness/appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) 'build/offtrack-roughness/localappdata'
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/offtrack-roughness-2026-11-03/roughness-headless.log' --script res://tests/test_offtrack_roughness.gd
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/offtrack-roughness-2026-11-03/off-road-retained.log' --script res://tests/test_off_road_suspension.gd
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/offtrack-roughness-2026-11-03/suspension-retained.log' --script res://tests/test_suspension.gd
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --position -16000,-16000 --rendering-method gl_compatibility --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/offtrack-roughness-2026-11-03/roughness-native-compatibility.log' --script res://tests/test_offtrack_roughness.gd -- --capture
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --position -16000,-16000 --rendering-method mobile --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/offtrack-roughness-2026-11-03/roughness-native-mobile.log' --script res://tests/test_offtrack_roughness.gd -- --capture
python docs/evidence/offtrack-roughness-2026-11-03/artifacts.py
```

[Native comparison playback](evidence/offtrack-roughness-2026-11-03/comparison.html), [Compatibility still](evidence/offtrack-roughness-2026-11-03/frames-gl_compatibility/020.png), [Mobile still](evidence/offtrack-roughness-2026-11-03/frames-mobile/020.png), [motion measurements](evidence/offtrack-roughness-2026-11-03/motion-metrics.json). The playback uses actual models and suspension with identical 12 m/s distance samples; its camera and flat staging grid are evidence only. The existing time-based surface rumble is omitted equally from both cars to isolate the distance-based response. This is not captured race driving.

The artifact command records source hashes and verifies forward/reverse application and exact contents of `task.patch` in a temporary directory. It never writes the main Git index. Earlier uncommitted suspension work and concurrent changes are preserved.

Reload and owner driving/appearance acceptance remain. Native rendered comparison covers Compact; other cars retain their existing compliance. No physical-device query/test, APK, owner-save/process change, live/backend access, deployment, commit or merge was performed. Device performance remains unmeasured.
