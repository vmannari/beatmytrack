# Later-lap stutter investigation, 2026-10-23

LLS01: investigate work that increases during a race. LLS02: remove confirmed tyre-mark visibility spikes while retaining the complete mark ring, exact appearance and driving behavior. R01/Q01: preserve concurrent work and record actual validation and device limits.

The owner reports smooth early tablet laps followed by stuttering. A confirmed source-side hotspot is present in the installed sign-in build: changing visible tyre-mark pages re-encodes every submitted transform, pigment and pressure value in GDScript, then submits the complete 1,310,720-byte MultiMesh buffer. More laps retain more overlapping mark pages. The frozen baseline is byte-identical to this file in the installed build's frozen source.

`game/vehicle/trail_visibility.gd` now encodes each mark once when it arrives. Camera selection copies contiguous packed pages using native array operations. A separate submitted buffer prevents renderer sharing from making the next canonical ring-buffer write duplicate the whole submitted view. There is still one MultiMesh, one draw, 16,384 retained slots, the same chronological page order, shader, bounds, sample spacing and overwrite behavior. Physics, records and lap rules are untouched.

These are desktop measurements of the visibility callback, not complete frame times or tablet FPS. The repeated-route fixture adds 3,276 marks per synthetic lap and revisits the same eight regions. It measures both implementations with alternating call order. Final Compatibility medians:

| Fixture lap | Retained marks | Original callback | Revised callback |
|---|---:|---:|---:|
| 1 | 3,276 | 2.405 ms | 1.196 ms |
| 2 | 6,552 | 4.032 ms | 1.131 ms |
| 3 | 9,828 | 5.221 ms | 1.347 ms |
| 4 | 13,104 | 6.907 ms | 1.624 ms |
| 5 | 16,380 | 8.419 ms | 1.438 ms |

The final desktop Mobile fifth-lap median is 7.616 to 0.715 ms; headless is 9.366 to 0.798 ms. The larger, deliberately wide stress view drops 11.285 to 1.547 ms in Compatibility. This does not establish how often each selection occurs on a real track. A single first activation in the repeated-route fixture encodes 3,276 existing marks and costs 5.426 ms versus the original 3.459 ms maximum; normal activation starts at 1,024 marks. Some desktop Mobile outliers remain and are retained in the reports. Encoding on arrival adds approximately 0.78 microseconds per mark in the Compatibility emission block. Full-buffer GPU submission and transparent overdraw remain; there is no graphics-quality reduction or claim to eliminate every possible stutter.

Actual tablet diagnostics were read without game input, restart, install or data changes. The original process remained PID 27442. Thermal status was 0 and reported cooling devices were inactive at the snapshot. One memory snapshot reported 788,461 KiB total PSS and 187,785 KiB swap PSS; this is insufficient to infer a leak or growth trend. A 126-timestamp compositor sample had 125 intervals of 19.998386–19.999375 ms, with no interval over 25 ms. It did **not** capture the reported later-lap stutter. The only saved hitch file was from an earlier process, with a 590.392 ms tick-zero event, so it does not explain the symptom. The existing monitor's 100 ms threshold also cannot exclude smaller stalls. Raw app hitch and thermal/memory copies remain private under `build/later-lap-stutter-2026-10-23`.

Validation used pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`:

- `-Action TestScript -ScriptPath res://tests/test_later_lap_trails.gd`: final 1,789 checks, zero failures.
- Same with `-Graphical -RenderingMethod gl_compatibility`: 1,795 checks, zero failures.
- Same with `-Graphical -RenderingMethod mobile -RenderingDriver vulkan`: 1,795 checks, zero failures.
- `-Action TestScript -ScriptPath res://tests/test_bridge_trails.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--folder=res://../build/later-lap-stutter-2026-10-23/bridge'`: 8 checks, zero failures; under-bridge protection retains zero protected-roof pixels against a 9,809-pixel unprotected control.
- `-Action TestScript -ScriptPath res://tests/test_trail_render_preparation.gd`: 26 checks, zero failures, including actual App loading and untouched race ring.
- `-Action TestScript -ScriptPath res://tests/test_script_parse.gd`: 1,025 scripts, zero failures.
- `git diff --check -- game/vehicle/trail_visibility.gd`: passes.

The focused test compares exact submitted transform/color/pressure buffers, populations and culling bounds against the frozen original through threshold activation, all camera regions, full rings, two overwrites, hidden/visible page growth, retry, projection changes and synthetic laps. Both native backends render byte-identical original/revised images containing actual tyre marks. See [Compatibility comparison](evidence/later-lap-stutter-2026-10-23/final-compatibility/trails-current.png) and [desktop Mobile comparison](evidence/later-lap-stutter-2026-10-23/final-desktop-mobile/trails-current.png).

Initial interruptions remain recorded: sandbox runtime log/ADB initialization failures were resolved using reviewed access; the first native pixel fixture retained a cached offscreen selection after an isolated world-transform probe, and was corrected by moving the camera while retaining the nonempty-draw assertion. The first bridge test was incorrectly invoked headless and waited for a draw signal; only that owned process was stopped, then its required graphical run passed. No production assertion was weakened. The original/current control before the code change passed 1,465 checks and had similar callback timings on both sides.

Changed task sources: `game/vehicle/trail_visibility.gd`, `game/tests/test_later_lap_trails.gd`, `game/tests/fixtures/later_lap_stutter_before/trail_visibility.gd.txt`; this note, task evidence, and the three repository status receipts. The generated task-only checkpoint excludes unrelated workspace changes.

Tablet symptom attribution and sustained owner driving acceptance remain pending with an updated build. This task performed read-only tablet diagnostics, not a driving/performance acceptance test. No APK was built or installed, no native library/backend was changed or deployed, and no active race was interrupted.
