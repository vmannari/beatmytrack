# Hovercraft Slide 5 variations — 2026-10-30

HS501: Develop five alternatives from the owner's selected Hovercraft Slide 5 and remove the earlier Slide 1–4 test options. HS502: Preserve the selected reference and the standard car, other cars and practice fences.

The race-view selector offers **Slide 5 (reference)** and **Slide 5.1–5.5**, alongside Current handling. The reference is exactly the former Slide 5 snapshot and identity. The five new configurations progressively reduce powered lateral damping from 0.9 to 0.5; the reference uses 1.0. Steering, yaw, coasting damping, powertrain, dimensions and controls remain the same. Lower damping lets the slide persist longer while applying thrust. This replaces the Hovercraft selector choices in `HOVER_SLIDE_VARIANTS_2026_10_30.md`. Selecting a test restarts as practice and cannot contribute a personal best or online result.

At 15 m/s initial speed, 0.7 steering and 65% throttle, the reference and 5.1–5.5 reach peak slip of 64.753°, 66.146°, 67.548°, 68.967°, 70.393° and 71.820° respectively. Four seconds after steering release, their remaining slip is 0.540°, 0.716°, 0.949°, 1.260°, 1.672° and 2.219°. These measurements describe one controlled test, not owner driving-feel acceptance or complete track coverage.

Pinned Godot 4.7.2 stable `ed1daf0bf` with isolated APPDATA/LOCALAPPDATA:

- `--headless --path game --script res://tests/test_hover_slide5_variants.gd`: 99 checks, zero failures: exact reference and current setup, differing damping, mirrored and deterministic 10/15/22 m/s maneuvers, progressive peak slip and recovery.
- `--headless --path game --script res://tests/test_hover_slide_variants.gd`: 83 checks, zero failures. Its original numerical assertions are retained using a historical five-choice control.
- `--headless --path game --script res://tests/test_handling_test_presets.gd`: zero failures across the current preset dynamics suite; `test_handling_test_selector.gd`: 33 checks, zero failures.
- `--headless --path game --script res://tests/test_handling_test_app.gd`: four checks, zero failures for practice results and ticket safeguards.
- `--path game --rendering-method gl_compatibility --script res://tests/capture_hover_slide5_variants.gd`: zero failures; actual Hovercraft race, mouse selection and practice restart at 960×540 and 1280×720. [Dropdown](evidence/hover-slide5-variants-2026-10-30/race-open-960x540.png), [selected variant](evidence/hover-slide5-variants-2026-10-30/race-960x540.png). `BMT_HANDLING_TEST_CAPTURE` points to the evidence directory.

The sandbox reported a Windows certificate-store error. Dynamics tests reported six ObjectDB instances and three resources in use at exit. The native capture logged race hitches, including a 16.8-second initial hitch; it is not a performance test. Owner feel and physical-device/touch acceptance remain. No device test, APK, live/backend or owner-save mutation, deployment or owner-process restart was performed.
