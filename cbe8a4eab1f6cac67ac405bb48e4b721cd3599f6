# Tutorial stopping and touch controls — 2026-10-25

Stopping inside the visible gold circle now advances the parking lesson. The lesson always teaches the saved on-screen touch controls and outlines the relevant accelerator, steering arrows/slider/joystick, or brake/pedal before the first touch. Reload the client to use the correction; **Settings → Help → Replay tutorial** remains available.

Two defects caused the stopping failure. The floor marker used positive simulation Y as world Z, while the car and camera use negative Y through `VisualGeometry.world`. This displaced the visible circle from the actual objective. Completion also required a brake press observed by the presentation loop; coasting and brief presses between presentation frames could leave an already-stopped player stuck.

| Requirement | Correction |
| --- | --- |
| TST01 | Floor markers use the same world conversion as the car. A continuous low-speed stop inside the actual circle completes after 24 advancing simulation ticks, without requiring a sampled brake press. The existing radius and speed threshold remain. Waiting outside, driving through, or rendering without simulation progress cannot finish the step. Leaving the circle resets the stop. |
| TST02 | All parking steps give touch instructions and draw outlines around the actual saved control rectangles. Buttons, horizontal slider and joystick modes, handedness, moved controls and safe insets remain supported. Keyboard/gamepad events leave this teaching visible; their normal driving inputs still work. The braking prompt explains releasing the control after slowing down. |
| R01 / G01 / Q01 | Native before/after captures, failing assertions, exact commands, source hashes and an isolated Git-checked patch are retained in the evidence directory. |

The runtime changes are confined to [the controller](../game/tutorial/tutorial_controller.gd) and [floor projection](../game/tutorial/tutorial_overlay.gd). The [focused harness](../game/tests/test_first_play_tutorial.gd) retains real quantized parking driving and the complete five-lap race, and adds:

- Stop-only and released-brake cases with 120 Hz physics and 30 Hz presentation sampling; stops outside/near the circle edge; leaving and returning; no progress from render-only frames.
- Native pixel checks locating all three visible target centers at their actual simulation positions.
- All three stages across all three saved touch methods, including native gold-border checks above the HUD and actual press/drag/release input through the overlay.
- Default highlights before the first touch and continued touch guidance after keyboard/gamepad events.

The previous assertion requiring a brake action after coasting is replaced by the user's requested stable-stop behavior. Other driving, storage, account/invitation, pause, layout, resource and race assertions remain. The test fixture also restores foreground presentation if a native resize delivers a delayed focus-out event before a button click; runtime background/pause behavior is unchanged.

See [the report](evidence/tutorial-stop-touch-2026-10-25/report.json) for exact results, commands and hashes, [the native gallery](evidence/tutorial-stop-touch-2026-10-25/report.html), and [the scoped patch](evidence/tutorial-stop-touch-2026-10-25/task-only.patch). Tests use pinned Godot 4.7.2 through `scripts/dev.ps1`, disposable workspace-local APPDATA and fixture saves, and no backend URL. Windows certificate-store access requires the isolated test processes to run outside the filesystem sandbox.

Retained failures include an initial typed-array error in the new test fixture; missing touch highlights and stop completion before the controller fix; all three displaced marker centers before the projection fix; and two desktop Mobile full-race diagnostics that stopped at two laps. The initial native reproduction also had two delayed-focus action failures. Extra pause/state diagnostics were added without changing the five-lap requirement; two subsequent Mobile runs completed all five laps in 12,753 simulation ticks each. No failing assertion is removed to obtain a pass. The earlier stalled runs did not capture enough state to establish their cause; this intermittent diagnostic failure remains an evidence limitation.

Physical touchscreen behavior and owner acceptance remain untested. No attachment check, device test, APK, deployment, live mutation, purchase or owner-process restart is performed. Concurrent changes are preserved. This correction does not change canonical simulation, saved progress format, race authority or online behavior. The older broad UI suite failures remain recorded in the [original tutorial report](FIRST_PLAY_TUTORIAL_2026_10_24.md); those unrelated suites are not rerun by this correction.
