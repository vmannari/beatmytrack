# Hovercraft Slide variations — 2026-10-30

HSV01: Replace the Hovercraft's Stable, Agile, Flow, Slide and Loose test choices with five variations of its previous Slide. HSV02: Keep the original Hovercraft handling available, and preserve Compact, other cars, online result fences and creator validation.

The eligible race-view dropdown now offers **Slide 1–5**. Slide 3 reproduces the former Slide configuration and test identity exactly. The other options retain its steering, yaw, coasting drag, powertrain and dimensions, varying only the powered lateral damping from 1.8 through 1.0 in steps of 0.2. A higher value catches lateral movement more quickly while applying thrust; a lower value lets the slide carry further. The standard **Current handling** remains available to restore the canonical car. Test selections still restart as practice and do not enter records or online standings. This supersedes the Hovercraft choice descriptions in `CAR_HANDLING_TEST_PRESETS_2026_10_30.md`; Volt's separate follow-up choices remain unchanged.

In an isolated 15 m/s, 0.7-steering, 65%-throttle sample, the five peak slip angles are 54.267°, 56.757°, 59.336°, 62.002° and 64.753°. After steering release and four more seconds of power the respective slip angles are 0.057°, 0.100°, 0.175°, 0.308° and 0.540°. This is a controlled sample, not a complete track test or a claim of human preference.

Pinned Godot 4.7.2 stable `ed1daf0bf`; each command used isolated APPDATA and LOCALAPPDATA:

- `--headless --path game --script res://tests/test_hover_slide_variants.gd`: 83 checks, zero failures. Exact original Slide and current handling, expected labels, damping-only changes, mirrored and repeatable 10/15/22 m/s turns, progressively increasing peak slip and release recovery.
- `--headless --path game --script res://tests/test_handling_test_presets.gd`: zero failures for the complete car-preset dynamics suite.
- `--headless --path game --script res://tests/test_handling_test_selector.gd`: 34 checks, zero failures.
- `--headless --path game --script res://tests/test_handling_test_integration.gd`: 16 checks, zero failures; `test_handling_test_app.gd`: four checks, zero failures.
- `--path game --rendering-method gl_compatibility --script res://tests/capture_hover_slide_variants.gd`: zero failures, actual Hovercraft race at 960×540 and 1280×720. Mouse opens the dropdown and selects test options, restarting as practice. [Open dropdown](evidence/hover-slide-variants-2026-10-30/race-open-960x540.png); [selected Slide 5](evidence/hover-slide-variants-2026-10-30/race-960x540.png). Set `BMT_HANDLING_TEST_CAPTURE` to the evidence directory for captures.

The offline sandbox runs reported a Windows root certificate-store error. The dynamics tests also reported six ObjectDB instances and three resources in use at exit. The graphical capture logged race hitches, including an initial 16-second hitch; no performance conclusion is drawn. Owner driving-feel acceptance and physical-device/touch testing remain. No device test, APK, owner-save or live/backend mutation, deployment or owner-process restart was performed.
