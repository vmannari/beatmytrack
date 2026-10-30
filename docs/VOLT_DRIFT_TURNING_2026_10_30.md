# Volt drift turning experiments — 2026-10-30

VT01: The owner likes Volt's drift starting point but reports understeer at speed. VT02: Provide five evolutions for quick comparison. VT03: Keep the prior Slide reference and all other car settings intact. These replace the Volt choices described in `CAR_HANDLING_TEST_PRESETS_2026_10_30.md`; the other cars retain their earlier options.

The dropdown now offers **Slide (reference)** and **Turn 1–5**, in addition to current standard handling. Slide has the exact prior Volt Slide snapshot and identity. The five alternatives retain its powered-drift response and progressively raise lateral grip and the speed-dependent turning envelope. They have separate test identities; standard Volt and Compact resources do not change. The existing experiment safeguards still restart a selection as practice and keep it out of personal bests and online results.

The reference's steering reduction, front grip saturation and continuous turning envelope all affect its path at speed. In an actual simulation sample with a 140 km/h entry, 70% steering and 65% throttle, travel direction changes 51.24° over one second with the reference, versus 57.28°, 61.38°, 65.95°, 71.48° and 76.79° for Turn 1–5. Speeds at the end are respectively 159.99 km/h for the reference and 157.95, 156.41, 154.55, 152.09 and 149.53 km/h for the alternatives. The car accelerates during the sample; these are not constant-speed turning radii. At 50 km/h and full steering, the reference's peak powered slip is 28.45°, versus 30.37–34.81° for the alternatives. These measurements do not establish subjective feel.

The candidates use turn acceleration values 85–120 above the existing editor hint maximum of 80; Turn 4–5 also use lateral grip 83–85 above its hint maximum of 80. These hints are not runtime clamps. The values are confined to the temporary test presets, and the checks below cover sampled behavior rather than every possible track or input.

Pinned Godot 4.7.2 stable `ed1daf0bf`, isolated APPDATA/LOCALAPPDATA:

- `--headless --path game --script res://tests/test_volt_turn_variants.gd`: 331 checks, zero failures. The reference snapshot is exact; candidates retain other fields, turn farther in the tested 100–180 km/h samples, retain powered drift, replay deterministically, mirror left/right and recover after release. Three-second full-power/full-lock tests followed by countersteer and release reached at most 41.25° slip and recovered in the tested cases.
- `--headless --path game --script res://tests/test_handling_test_presets.gd`: zero failures, including all six Volt choices and the existing other-car tests.
- `--headless --path game --script res://tests/test_handling_test_integration.gd`: 16 checks, zero failures, including restart, practice and creator-validation fences.
- `--headless --path game --script res://tests/test_handling_test_selector.gd`: 29 checks, zero failures.
- `--path game --rendering-method gl_compatibility --script res://tests/capture_handling_test_race.gd`: zero failures. Mouse selection of Turn 5 at 960×540 and Turn 1 at 1280×720 restarted the actual Electric race as practice. [Open dropdown at 960×540](evidence/volt-drift-turning-2026-10-30/race-open-960x540.png) and [1280×720](evidence/volt-drift-turning-2026-10-30/race-open-1280x720.png). The capture used an isolated profile and `BMT_HANDLING_TEST_CAPTURE` output directory.

The offline runs logged a Windows root certificate-store warning; the dynamics run also reported resources still in use at exit. The desktop capture logged hitches, including a 17.66-second initial frame. Owner driving-feel acceptance and touch/physical-device testing remain open. No device test, APK, live/backend write, owner-save mutation or owner-process restart was performed.
