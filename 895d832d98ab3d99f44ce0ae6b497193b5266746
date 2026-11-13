# Broader off-track height variation — 2026-11-02

OTH01: Increase low-frequency terrain response so driving off track visibly rises, falls, pitches and rolls. OTH02: Preserve the existing wheel-specific, distance-based presentation and protected-surface exclusions. R01/Q01: Verify the rendered response and retain a task-only review checkpoint.

`game/track/native_track.gd` changes the existing presentation ground profile from 48/28 mm waves to 120/75 mm waves. Their spatial wavelengths increase from approximately 10.5/14.5 m to 17.3/23.8 m. The smaller 12/8 mm irregularities are retained. Broad vertical amplitude can reach 195 mm before fine detail, wheel averaging and spring damping. Road, bridge, airborne, rollover, stationary and air-cushion exclusions remain. This changes the sampled visual suspension profile; it does not deform the rendered terrain mesh or change canonical simulation, collision, grip, scoring or replay contracts.

`game/tests/test_offtrack_broad_height.gd` exercises the actual Compact suspension at 5, 12 and 22 m/s in four headings, measures broad heave after damping, checks low-frequency travel over a fixed spatial averaging window, and checks deterministic snapshots, protected surfaces, smooth travel and independent duplicate renders. It also provides an optional staged native before/after capture using the exact former profile as the control.

Observed Compact body heave range is 0.239–0.371 m over the twelve paths. At 12 m/s it is 0.327–0.371 m, versus the former profile's **undamped** wheel-average range of 0.135–0.143 m. This is a conservative comparison against the previous input, not a measurement of the previous damped body. Pitch/roll ranges at 12 m/s are 3.04–5.54° / 2.94–5.73°. Slow travel dominates with the same 2.4 m spatial averaging window at every speed. See [motion-metrics.json](evidence/offtrack-broad-height-2026-11-02/motion-metrics.json).

Actual checks:

| Command target | Result |
| --- | --- |
| `test_offtrack_broad_height.gd`, headless | 67 checks, 0 failures |
| unchanged `test_off_road_suspension.gd`, headless | 13 checks, 0 failures |
| unchanged `test_suspension.gd`, headless | 59 checks, 0 failures |
| `test_offtrack_broad_height.gd -- --capture`, native Compatibility | 128 checks, 0 failures, including 61 native frames |

Commands ran from the repository root. `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_off_road_suspension.gd -CommandTimeoutSeconds 90` first hit PowerShell's execution policy. Retrying through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ...` (also for the new test) reached Godot but failed opening the owner's default `user://logs` folder. The dev entry point printed the pinned engine version and regenerated local build identity; that incidental metadata is excluded from the checkpoint.

Successful fallback commands used an isolated writable user directory and the same pinned engine. Before each command, set process-local `APPDATA` and `LOCALAPPDATA` to the absolute paths of `build/offtrack-broad-height/appdata` and `build/offtrack-broad-height/localappdata`. Then run:

```powershell
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/offtrack-broad-height-2026-11-02/broad-headless.log' --script res://tests/test_offtrack_broad_height.gd
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/offtrack-broad-height-2026-11-02/suspension-retained.log' --script res://tests/test_off_road_suspension.gd
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/offtrack-broad-height-2026-11-02/general-suspension.log' --script res://tests/test_suspension.gd
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --position -16000,-16000 --rendering-method gl_compatibility --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/offtrack-broad-height-2026-11-02/broad-native.log' --script res://tests/test_offtrack_broad_height.gd -- --capture
```

The first new-test run retained two failed slow-travel assertions: a fixed 0.2 s averaging window covered different distances at different speeds. The fixture now averages over 2.4 m at every speed; the 65% dominance requirement is unchanged. Initial metrics are retained in `motion-metrics-initial.json`. The first fallback also passed a relative log filename, which Godot rejected; all final commands use absolute log filenames. Every final launch reports the sandbox's root-certificate-store warning; no network is used by these tests and all final process exit codes are zero.

[Native comparison playback](evidence/offtrack-broad-height-2026-11-02/comparison.html) and [still frame](evidence/offtrack-broad-height-2026-11-02/frames/020.png) show the two actual Compact models with identical 12 m/s distance samples. This is a staged close comparison, not captured race driving or a changed shipping camera. The smaller rumble is omitted equally from both cars to make the broad suspension response readable. Playback is a standalone HTML file with embedded frames, play/pause and a scrubber. Pillow was unavailable in both installed Python versions, and WSL access was denied, so the final artifact builder uses only Python's standard library.

`python docs/evidence/offtrack-broad-height-2026-11-02/artifacts.py` creates the animation and a task-only Git patch from the recorded task-start runtime source. It checks forward/reverse application and exact resulting contents in a temporary directory, without writing the main Git index. The earlier uncommitted suspension implementation and concurrent work are preserved.

Reload and owner driving/appearance acceptance remain. No phone/device test, APK, live/backend operation, deployment, owner-save change, owner-process restart, commit or merge was performed. No frame-rate or device-performance claim is made. The rendered native comparison covers Compact; the other cars retain their existing compliance and clearance behavior.
