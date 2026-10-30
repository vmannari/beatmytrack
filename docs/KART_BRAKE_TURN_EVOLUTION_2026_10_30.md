# Kart Brake turn evolution — 2026-10-30

KBE01: Evolve the owner's preferred Brake turn for quick comparison. The race-view dropdown keeps the exact earlier **Brake turn (reference)** and presents five progressively stronger **Brake turn 1–5** alternatives; the other experimental kart choices are removed. **Current handling** remains available as the original canonical car. Other cars' settings are unchanged.

The reference retains its original complete configuration, profile name and `kart-7-kart-refine-4` identity. Each alternative derives from it and changes braking rotation, brake grip loss and countersteer assistance; steering geometry, engine, braking force and speed limit remain. Each alternative has a separate experimental identity. Selecting any test still restarts as practice with the existing record, upload and rewind safeguards.

On the pinned Godot 4.7.2 (`ed1daf0bf`) in isolated local profiles:

- `--headless --path game --script res://tests/test_kart_brake_turn_evolution.gd`: 73 checks, zero failures. Exact preferred-reference snapshot, progressively increasing rotation, mirrored steering, deterministic replays and recovery pass. The speed/brake matrix covers 12, 20 and 30 m/s with 35% and 80% brake. In the 25 m/s, 70% steering, 35% brake, half-second sample, heading increases by 0.81°, 1.76°, 2.63°, 3.43° and 4.32° relative to the reference. These are controlled samples, not lap or owner-feel measurements.
- `--headless --path game --script res://tests/test_handling_test_presets.gd`: zero failures; finite state, recovery, replay and pairwise differences. Kart distinctness is measured under braking, where the new variants differ.
- `--headless --path game --script res://tests/test_handling_test_selector.gd`: 32 checks, zero failures, including reference and option labels. `res://tests/test_handling_test_integration.gd`: 18 checks, zero failures for restart, practice and related fences.
- `--headless --path game --script res://tests/test_kart_handling_refinements.gd`: 22 checks, zero failures. This historical regression now reads its retained original preset fixture, preserving the earlier assertions.
- `--path game --rendering-method gl_compatibility --script res://tests/capture_kart_brake_turn_evolution.gd`: zero failures, actual kart race with mouse selection at 960×540 and 1280×720. [Open menu](evidence/kart-brake-turn-evolution-2026-10-30/race-open-960x540.png). Captures used isolated APPDATA/LOCALAPPDATA and `BMT_HANDLING_TEST_CAPTURE` output directory.

Offline Windows runs logged a certificate-store warning; simulation fixtures reported resources still in use at exit. The graphical run logged hitches, including a cold 22.56 s frame. No physical-device test, owner-save write, APK, deployment or owner-process restart was performed. Owner driving-feel acceptance remains open.
