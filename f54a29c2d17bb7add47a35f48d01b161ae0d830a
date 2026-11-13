# Kart Brake turn 5: less understeer — 2026-10-30

KBT501: The owner likes Brake turn 5 but reports some understeer. Its exact configuration and `kart-7-kart-brake-5` identity remain available as **Brake turn 5 (reference)**. Five alternatives, **Brake turn 5.1–5.5**, progressively raise lateral grip and reduce the steering reduction at speed. All derive from the chosen tune and retain its brake rotation, brake grip loss, countersteer assistance, engine, braking force, speed limit and dimensions. The original canonical car remains available as Current handling. Other cars are unchanged. Test choices remain practice-only.

The grip values extend above the handling resource's editor slider maximum; the simulation uses the values directly. They are local experiments, not changes to the kart resource or canonical contract. Higher grip and lock may trade speed and feel for turning, and require owner assessment.

Pinned Godot 4.7.2 `ed1daf0bf`, offline with isolated profiles:

- `--headless --path game --script res://tests/test_kart_brake_turn5_turning.gd`: 107 checks, zero failures. Reference snapshot matches the task-start fixture. Each candidate turns the **velocity direction** more than the preceding choice in powered and braking samples, preserves brake parameters and is symmetric in the mirrored braking sample. At 25 m/s initial speed, 70% steering and half a second, powered direction gain versus reference is 3.87–19.45° across the five; braking at 35% gains 1.95–3.72°. In that powered sample, end speed ranges 27.19–26.30 m/s versus reference 27.38 m/s. Recovery and exact replay pass at 12, 20 and 30 m/s and 0%, 35% and 80% brake. Samples do not prove lap performance or subjective feel.
- `--headless --path game --script res://tests/test_handling_test_presets.gd`: zero failures, including finite state, recovery, replay and distinct turning trajectories for available test cars.
- `--headless --path game --script res://tests/test_handling_test_selector.gd`: 31 checks, zero failures. `res://tests/test_handling_test_integration.gd`: 20 checks, zero failures.
- `--headless --path game --script res://tests/test_kart_brake_turn_evolution.gd`: 73 checks, zero failures; the earlier regression uses a task-start copy of the former test definitions so its historical assertions remain intact.
- `--path game --rendering-method gl_compatibility --script res://tests/capture_kart_brake_turn_evolution.gd`: zero failures, mouse selection in the actual kart race at 960×540 and 1280×720. [Open dropdown](evidence/kart-brake-turn5-2026-10-30/race-open-960x540.png). The capture used `BMT_HANDLING_TEST_CAPTURE` and isolated APPDATA/LOCALAPPDATA.

Windows logged a certificate-store warning, the headless simulation reported resources still in use at exit, and graphical capture logged hitches including a 20.0-second cold frame. No physical-device test, owner-save mutation, APK, deployment or owner-process restart was performed. Owner driving-feel acceptance remains open.
